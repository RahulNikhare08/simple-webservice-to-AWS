# Simple Web Service to AWS

A complete CI/CD setup for deploying a Node.js web service to AWS using ECS Fargate with Terraform and GitHub Actions.

## Architecture

- **VPC**: Public and private subnets across 2 AZs
- **ECS Fargate**: Containerized Node.js app in private subnets
- **Application Load Balancer**: HTTPS with self-signed certificate
- **Secrets Manager**: Database connection string storage
- **CloudWatch**: CPU and memory alarms
- **ECR**: Container image registry

## Features

- ✅ HTTPS with automatic HTTP→HTTPS redirect
- ✅ Self-signed SSL certificate
- ✅ Secrets Manager integration
- ✅ CloudWatch monitoring and alarms
- ✅ Complete CI/CD pipeline
- ✅ Infrastructure as Code with Terraform
- ✅ Automated smoke tests

## Prerequisites

1. AWS Account with appropriate permissions
2. GitHub repository with secrets configured:
   - `AWS_ROLE_TO_ASSUME`: IAM role ARN for GitHub Actions

## Deployment

### Automatic (GitHub Actions)
Push to `main` branch or trigger workflow manually to deploy.

### Manual
```bash
cd infra
terraform init
terraform plan
terraform apply
```

## Testing

The application exposes a JSON API at `/`:
```json
{
  "message": "Hello World from ECS Fargate! 🎉",
  "db_url_env_present": true,
  "db_url": "[REDACTED]",
  "time": "2025-08-30T12:22:25.367Z",
  "version": "1.0.0"
}
```

## Cleanup

Use the destroy workflow with confirmation or run:
```bash
cd infra
terraform destroy
```

## Monitoring

CloudWatch alarms monitor:
- CPU utilization > 80%
- Memory utilization > 80%
