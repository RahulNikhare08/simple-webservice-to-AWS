#!/bin/bash

cd infra

echo "Initializing Terraform..."
terraform init

echo "Importing existing AWS resources..."

# Import ECR repository
echo "Importing ECR repository..."
terraform import aws_ecr_repository.repo hello-fargate || echo "ECR import failed"

# Import VPC
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=hello-fargate-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "" ]; then
    echo "Importing VPC: $VPC_ID"
    terraform import aws_vpc.main $VPC_ID || echo "VPC import failed"
fi

# Import Internet Gateway
IGW_ID=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[0].InternetGatewayId' --output text 2>/dev/null)
if [ "$IGW_ID" != "None" ] && [ "$IGW_ID" != "" ]; then
    echo "Importing Internet Gateway: $IGW_ID"
    terraform import aws_internet_gateway.igw $IGW_ID || echo "IGW import failed"
fi

# Import Subnets
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" "Name=tag:Name,Values=hello-fargate-public-*" --query 'Subnets[].SubnetId' --output text 2>/dev/null)
i=0
for SUBNET_ID in $SUBNET_IDS; do
    echo "Importing Subnet[$i]: $SUBNET_ID"
    terraform import "aws_subnet.public[$i]" $SUBNET_ID || echo "Subnet import failed"
    ((i++))
done

# Import ECS Cluster
echo "Importing ECS Cluster..."
terraform import aws_ecs_cluster.main hello-fargate || echo "ECS cluster import failed"

# Import ALB
ALB_ARN=$(aws elbv2 describe-load-balancers --names hello-fargate-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null)
if [ "$ALB_ARN" != "None" ] && [ "$ALB_ARN" != "" ]; then
    echo "Importing ALB: $ALB_ARN"
    terraform import aws_lb.app $ALB_ARN || echo "ALB import failed"
fi

# Import Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names hello-fargate-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null)
if [ "$TG_ARN" != "None" ] && [ "$TG_ARN" != "" ]; then
    echo "Importing Target Group: $TG_ARN"
    terraform import aws_lb_target_group.app $TG_ARN || echo "Target group import failed"
fi

echo "Import completed. Run 'terraform plan' to see the current state."
