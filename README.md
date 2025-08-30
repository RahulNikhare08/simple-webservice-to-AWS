# Simple Web Service to AWS

A complete CI/CD setup for deploying a Node.js web service to AWS using ECS Fargate with Terraform and GitHub Actions.

## Architecture

- **VPC**: Public and private subnets across 2 AZs
- **ECS Fargate**: Containerized Node.js app in private subnets
- **Application Load Balancer**: HTTPS with self-signed certificate
- **Secrets Manager**: Database connection string storage
- **CloudWatch**: CPU and memory alarms
- **ECR**: Container image registry
- **S3**: Remote Terraform state storage

## Features

- ✅ HTTPS with automatic HTTP→HTTPS redirect
- ✅ Self-signed SSL certificate
- ✅ Secrets Manager integration
- ✅ CloudWatch monitoring and alarms
- ✅ Complete CI/CD pipeline with GitHub Actions
- ✅ Infrastructure as Code with Terraform
- ✅ Remote state storage in S3
- ✅ Automated smoke tests

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **GitHub Repository** 
3. **Local Tools**:
   - AWS CLI configured
   - Terraform >= 1.5.0
   - Docker
   - Git

## Setup Instructions

### 1. Clone Repository
```bash
git clone https://github.com/YOUR_USERNAME/simple-webservice-to-AWS.git
cd simple-webservice-to-AWS
```

### 2. AWS Configuration
```bash
# Configure AWS CLI
aws configure

# Verify access
aws sts get-caller-identity
```

### 3. Deploy Infrastructure (First Time)

#### Manual Deployment
```bash
cd infra
terraform init
terraform plan
terraform apply
```

#### Get GitHub Actions Role ARN
```bash
terraform output github_actions_role_arn
```

### 4. Configure GitHub Actions

#### Add Repository Secret
1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Add new repository secret:
   - **Name**: `AWS_ROLE_TO_ASSUME`
   - **Value**: `arn:aws:iam::YOUR_ACCOUNT:role/github-actions-role`

### 5. Test Deployment

#### Trigger Workflow
- Push to `main` branch, or
- Go to Actions tab → "Deploy to AWS" → "Run workflow"

#### Manual Testing
```bash
# Get ALB DNS name
cd infra
ALB_DNS=$(terraform output -raw alb_dns_name)

# Test HTTP redirect
curl -I http://$ALB_DNS/

# Test HTTPS application (ignore self-signed cert)
curl -k https://$ALB_DNS/
```

## Application API

The service exposes a JSON API at `/`:

```json
{
  "message": "Hello World from ECS Fargate! 🎉",
  "db_url_env_present": true,
  "db_url": "[REDACTED]",
  "time": "2025-08-30T14:47:00.000Z",
  "version": "1.0.1"
}
```

## Infrastructure Components

### Networking
- **VPC**: `10.0.0.0/16`
- **Public Subnets**: `10.0.1.0/24`, `10.0.2.0/24`
- **Private Subnets**: `10.0.101.0/24`, `10.0.102.0/24`
- **NAT Gateways**: One per AZ for private subnet internet access

### Security
- **ALB Security Group**: Allows HTTP (80) and HTTPS (443) from internet
- **ECS Security Group**: Allows traffic from ALB only
- **IAM Roles**: 
  - ECS Task Execution Role
  - ECS Task Role (with Secrets Manager access)
  - GitHub Actions Role (OIDC)

### SSL Certificate
- **Type**: Self-signed certificate
- **Algorithm**: RSA 2048-bit
- **Validity**: 1 year
- **Common Name**: `*.elb.amazonaws.com`

### Monitoring
- **CPU Alarm**: Triggers when > 80%
- **Memory Alarm**: Triggers when > 80%
- **CloudWatch Logs**: `/ecs/hello-fargate`

## CI/CD Pipeline

### GitHub Actions Workflow
1. **Checkout** code
2. **Configure AWS** credentials via OIDC
3. **Setup Terraform**
4. **Plan** infrastructure changes
5. **Build & Push** Docker image to ECR
6. **Deploy** infrastructure with Terraform
7. **Wait** for ECS service stabilization
8. **Run Smoke Tests**:
   - HTTP redirect test
   - HTTPS application test
   - Database connection test

### Workflow Triggers
- Push to `main` branch
- Manual workflow dispatch

## File Structure

```
.
├── app/
│   ├── server.js          # Node.js application
│   └── package.json       # Dependencies
├── infra/
│   ├── main.tf           # Terraform configuration
│   ├── terraform.tfvars.example
│   └── terraform.tfstate # Local state (migrated to S3)
├── .github/
│   └── workflows/
│       ├── deploy.yml    # CI/CD pipeline
│       └── destroy.yml   # Infrastructure cleanup
├── Dockerfile            # Container definition
├── cleanup.sh           # Resource cleanup script
├── network-cleanup.sh   # Network cleanup script
└── README.md           # This file
```

## Configuration Variables

### Terraform Variables
```hcl
variable "region" {
  default = "us-east-1"
}

variable "image_tag" {
  default = "latest"
}
```

### Environment Variables (ECS)
- `PORT`: Application port (3000)
- `DB_URL`: Database connection string (from Secrets Manager)

## Troubleshooting

### Common Issues

#### 1. Resource Already Exists
```bash
# Import existing resources
./import-resources.sh
```

#### 2. GitHub Actions Permission Denied
- Verify `AWS_ROLE_TO_ASSUME` secret is set correctly
- Check IAM role trust policy includes your repository

#### 3. ECS Service Won't Start
```bash
# Check ECS service events
aws ecs describe-services --cluster hello-fargate --services hello-fargate

# Check CloudWatch logs
aws logs tail /ecs/hello-fargate --follow
```

#### 4. SSL Certificate Issues
- Self-signed certificates will show browser warnings
- Use `curl -k` to bypass certificate validation for testing

### Cleanup Commands

#### Destroy Infrastructure
```bash
# Via GitHub Actions
# Go to Actions → "Destroy Infrastructure" → Run workflow

# Or manually
cd infra
terraform destroy
```

#### Complete Cleanup
```bash
./cleanup.sh
```

## Security Considerations

### Production Recommendations
1. **Replace self-signed certificate** with ACM-managed certificate
2. **Restrict IAM policies** (currently using AdministratorAccess for demo)
3. **Enable VPC Flow Logs**
4. **Add WAF** for additional protection
5. **Use Parameter Store** instead of Secrets Manager for non-sensitive config
6. **Enable GuardDuty** for threat detection

### Current Security Features
- Private subnets for application containers
- Security groups with minimal required access
- Secrets Manager for sensitive data
- HTTPS encryption with redirect from HTTP
- IAM roles with least privilege (except GitHub Actions role)

## Monitoring & Observability

### CloudWatch Metrics
- ECS service CPU/Memory utilization
- ALB request count and latency
- Custom application metrics (if implemented)

### Alarms
- High CPU utilization (>80%)
- High memory utilization (>80%)

### Logs
- Application logs: `/ecs/hello-fargate`
- ALB access logs: (can be enabled)

## Cost Optimization

### Current Resources
- **ECS Fargate**: ~$30-50/month (0.25 vCPU, 0.5GB RAM)
- **ALB**: ~$20/month
- **NAT Gateways**: ~$90/month (2 gateways)
- **Other**: <$10/month

### Cost Reduction Options
1. **Single NAT Gateway** (reduces availability)
2. **Smaller Fargate tasks**
3. **Scheduled scaling** (scale down during off-hours)
4. **Reserved capacity** for predictable workloads

## Development Workflow

### Local Development
```bash
# Run locally
cd app
npm install
npm start

# Test locally
curl http://localhost:3000
```

### Making Changes
1. Modify code in `app/` directory
2. Update version in `server.js`
3. Commit and push to `main` branch
4. GitHub Actions automatically deploys

### Infrastructure Changes
1. Modify `infra/main.tf`
2. Test locally: `terraform plan`
3. Commit and push
4. GitHub Actions applies changes

## Support

For issues or questions:
1. Check CloudWatch logs
2. Review GitHub Actions workflow logs
3. Verify AWS resource status in console
4. Use troubleshooting commands above

## License

MIT License - see LICENSE file for details.
