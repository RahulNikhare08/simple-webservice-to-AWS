#!/bin/bash

echo "Checking existing AWS resources..."

# Check ECR repository
echo "=== ECR Repository ==="
aws ecr describe-repositories --repository-names hello-fargate 2>/dev/null || echo "ECR repository not found"

# Check VPC
echo "=== VPC ==="
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=hello-fargate-vpc" --query 'Vpcs[0].VpcId' --output text 2>/dev/null)
if [ "$VPC_ID" != "None" ] && [ "$VPC_ID" != "" ]; then
    echo "VPC found: $VPC_ID"
else
    echo "VPC not found"
fi

# Check ECS Cluster
echo "=== ECS Cluster ==="
aws ecs describe-clusters --clusters hello-fargate --query 'clusters[0].clusterName' --output text 2>/dev/null || echo "ECS cluster not found"

# Check ALB
echo "=== Application Load Balancer ==="
aws elbv2 describe-load-balancers --names hello-fargate-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "ALB not found"

# Check Target Group
echo "=== Target Group ==="
aws elbv2 describe-target-groups --names hello-fargate-tg --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || echo "Target group not found"
