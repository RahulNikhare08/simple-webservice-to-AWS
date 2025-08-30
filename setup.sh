#!/bin/bash
set -e

echo "🚀 Smart Infrastructure Setup"
echo "=============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to check if resource exists
check_resource() {
    local resource_type=$1
    local resource_name=$2
    local check_command=$3
    
    echo -n "Checking $resource_type '$resource_name'... "
    if eval $check_command > /dev/null 2>&1; then
        echo -e "${GREEN}EXISTS${NC}"
        return 0
    else
        echo -e "${RED}NOT FOUND${NC}"
        return 1
    fi
}

# Function to create resource if it doesn't exist
create_if_missing() {
    local resource_type=$1
    local resource_name=$2
    local check_command=$3
    local create_command=$4
    
    if ! check_resource "$resource_type" "$resource_name" "$check_command"; then
        echo -e "${YELLOW}Creating $resource_type '$resource_name'...${NC}"
        eval $create_command
        echo -e "${GREEN}✅ Created $resource_type '$resource_name'${NC}"
    else
        echo -e "${BLUE}ℹ️  Using existing $resource_type '$resource_name'${NC}"
    fi
}

echo ""
echo "🔍 Checking Prerequisites..."
echo "----------------------------"

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI not found. Please install AWS CLI first.${NC}"
    exit 1
fi

# Check if AWS is configured
if ! aws sts get-caller-identity > /dev/null 2>&1; then
    echo -e "${RED}❌ AWS CLI not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${GREEN}✅ AWS CLI configured for account: $ACCOUNT_ID${NC}"

echo ""
echo "🏗️  Setting up Core Resources..."
echo "--------------------------------"

# Create S3 bucket for Terraform state
create_if_missing "S3 Bucket" "hello-fargate-terraform-state" \
    "aws s3api head-bucket --bucket hello-fargate-terraform-state" \
    "aws s3api create-bucket --bucket hello-fargate-terraform-state --region us-east-1 && aws s3api put-bucket-versioning --bucket hello-fargate-terraform-state --versioning-configuration Status=Enabled"

# Create ECR repository
create_if_missing "ECR Repository" "hello-fargate" \
    "aws ecr describe-repositories --repository-names hello-fargate" \
    "aws ecr create-repository --repository-name hello-fargate"

# Check for GitHub OIDC provider
create_if_missing "GitHub OIDC Provider" "token.actions.githubusercontent.com" \
    "aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com" \
    "aws iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1"

# Create GitHub Actions IAM role
GITHUB_REPO=$(git config --get remote.origin.url | sed 's/.*github.com[:/]\([^/]*\/[^/]*\)\.git/\1/' | sed 's/.*github.com[:/]\([^/]*\/[^/]*\)/\1/')
if [ -z "$GITHUB_REPO" ]; then
    echo -e "${YELLOW}⚠️  Could not detect GitHub repository. Using wildcard pattern.${NC}"
    GITHUB_REPO="*"
fi

TRUST_POLICY=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::$ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:$GITHUB_REPO:*"
        }
      }
    }
  ]
}
EOF
)

if ! check_resource "IAM Role" "github-actions-role" "aws iam get-role --role-name github-actions-role"; then
    echo -e "${YELLOW}Creating GitHub Actions IAM role...${NC}"
    aws iam create-role --role-name github-actions-role --assume-role-policy-document "$TRUST_POLICY"
    aws iam attach-role-policy --role-name github-actions-role --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
    echo -e "${GREEN}✅ Created GitHub Actions IAM role${NC}"
else
    echo -e "${BLUE}ℹ️  Using existing GitHub Actions IAM role${NC}"
fi

# Handle Secrets Manager secret
if aws secretsmanager describe-secret --secret-id hello-fargate-db-connection > /dev/null 2>&1; then
    SECRET_STATUS=$(aws secretsmanager describe-secret --secret-id hello-fargate-db-connection --query 'DeletedDate' --output text)
    if [ "$SECRET_STATUS" != "None" ]; then
        echo -e "${YELLOW}Restoring scheduled-for-deletion secret...${NC}"
        aws secretsmanager restore-secret --secret-id hello-fargate-db-connection
        echo -e "${GREEN}✅ Restored Secrets Manager secret${NC}"
    else
        echo -e "${BLUE}ℹ️  Using existing Secrets Manager secret${NC}"
    fi
else
    echo -e "${YELLOW}Creating Secrets Manager secret...${NC}"
    aws secretsmanager create-secret --name hello-fargate-db-connection --description "Database connection string for hello-fargate app"
    aws secretsmanager put-secret-value --secret-id hello-fargate-db-connection --secret-string "postgresql://user:password@localhost:5432/hello_fargate_db"
    echo -e "${GREEN}✅ Created Secrets Manager secret${NC}"
fi

echo ""
echo "🔧 Terraform Setup..."
echo "---------------------"

cd infra

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Import existing resources if they exist in AWS but not in state
echo "Checking for resources to import..."

# Import GitHub Actions role if it exists but not in state
if ! terraform state show aws_iam_role.github_actions > /dev/null 2>&1; then
    if aws iam get-role --role-name github-actions-role > /dev/null 2>&1; then
        echo "Importing GitHub Actions role..."
        terraform import aws_iam_role.github_actions github-actions-role
    fi
fi

# Import Secrets Manager secret if it exists but not in state
if ! terraform state show aws_secretsmanager_secret.db_connection > /dev/null 2>&1; then
    SECRET_ARN=$(aws secretsmanager describe-secret --secret-id hello-fargate-db-connection --query 'ARN' --output text 2>/dev/null || echo "")
    if [ ! -z "$SECRET_ARN" ]; then
        echo "Importing Secrets Manager secret..."
        terraform import aws_secretsmanager_secret.db_connection "$SECRET_ARN"
    fi
fi

cd ..

echo ""
echo -e "${GREEN}🎉 Setup Complete!${NC}"
echo "=================="
echo ""
echo "📋 Next Steps:"
echo "1. Add GitHub repository secret:"
echo "   - Name: AWS_ROLE_TO_ASSUME"
echo "   - Value: arn:aws:iam::$ACCOUNT_ID:role/github-actions-role"
echo ""
echo "2. Push to main branch or run GitHub Actions workflow to deploy"
echo ""
echo "💰 Estimated monthly cost: ~$150-170"
echo "🔗 GitHub repo detected: $GITHUB_REPO"
echo ""
echo -e "${BLUE}ℹ️  All core resources are now ready for deployment!${NC}"
