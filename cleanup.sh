#!/bin/bash
set -e

echo "🧹 Cleaning up existing AWS resources..."

# Delete ECS Service first (has dependencies)
echo "Deleting ECS service..."
aws ecs update-service --cluster hello-fargate --service hello-fargate --desired-count 0 --region us-east-1 || true
aws ecs delete-service --cluster hello-fargate --service hello-fargate --region us-east-1 || true

# Wait for service deletion
echo "Waiting for service deletion..."
sleep 30

# Delete ECS Cluster
echo "Deleting ECS cluster..."
aws ecs delete-cluster --cluster hello-fargate --region us-east-1 || true

# Delete Load Balancer
echo "Deleting load balancer..."
ALB_ARN=$(aws elbv2 describe-load-balancers --names hello-fargate-alb --query 'LoadBalancers[0].LoadBalancerArn' --output text --region us-east-1 2>/dev/null || echo "")
if [ "$ALB_ARN" != "" ] && [ "$ALB_ARN" != "None" ]; then
    aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region us-east-1
    echo "Waiting for ALB deletion..."
    sleep 60
fi

# Delete Target Group
echo "Deleting target group..."
TG_ARN=$(aws elbv2 describe-target-groups --names hello-fargate-tg --query 'TargetGroups[0].TargetGroupArn' --output text --region us-east-1 2>/dev/null || echo "")
if [ "$TG_ARN" != "" ] && [ "$TG_ARN" != "None" ]; then
    aws elbv2 delete-target-group --target-group-arn $TG_ARN --region us-east-1
fi

# Delete IAM Roles
echo "Deleting IAM roles..."
aws iam detach-role-policy --role-name hello-fargate-ecs-execution --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy --region us-east-1 || true
aws iam delete-role-policy --role-name hello-fargate-ecs-execution --policy-name hello-fargate-execution-secrets-policy --region us-east-1 || true
aws iam delete-role --role-name hello-fargate-ecs-execution --region us-east-1 || true

aws iam delete-role-policy --role-name hello-fargate-ecs-task --policy-name hello-fargate-secrets-policy --region us-east-1 || true
aws iam delete-role --role-name hello-fargate-ecs-task --region us-east-1 || true

# Delete Secrets Manager
echo "Deleting secrets..."
aws secretsmanager delete-secret --secret-id hello-fargate-db-connection --force-delete-without-recovery --region us-east-1 || true

# Delete CloudWatch Log Group
echo "Deleting log group..."
aws logs delete-log-group --log-group-name /ecs/hello-fargate --region us-east-1 || true

echo "✅ Cleanup completed! You can now run terraform apply."
