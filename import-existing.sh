#!/bin/bash
set -e

echo "Importing existing resources into Terraform state..."

cd infra

# Initialize Terraform
terraform init

# Import GitHub Actions role
echo "Importing GitHub Actions role..."
terraform import aws_iam_role.github_actions github-actions-role || true

# Import Secrets Manager secret
echo "Importing Secrets Manager secret..."
terraform import aws_secretsmanager_secret.db_connection hello-fargate-db-connection || true

# Import ECR repository
echo "Importing ECR repository..."
terraform import data.aws_ecr_repository.repo hello-fargate || true

echo "Import completed!"
