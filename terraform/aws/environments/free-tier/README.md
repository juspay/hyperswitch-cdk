# Free Tier Environment

## Description
Complete Hyperswitch payment processing platform optimized for AWS Free Tier. Deploys payment router API, control center dashboard, and SDK server with PostgreSQL database and Redis cache across two t2.micro EC2 instances.

## Resources Created (67 total)
- **VPC & Networking**: 1 VPC, 1 Internet Gateway, 4 Subnets, 1 NAT Gateway, 1 EIP, 2 Route Tables, 4 Route Table Associations
- **Security Groups**: 4 Security Groups, 19 Security Group Rules  
- **Load Balancer**: 1 ALB, 3 Target Groups, 3 Listeners, 3 Target Group Attachments
- **CloudFront**: 3 Distributions (app, control center, SDK)
- **Database**: 1 RDS PostgreSQL (db.t3.micro, 20GB), 1 Subnet Group, 1 Parameter Group
- **Cache**: 1 ElastiCache Redis (cache.t3.micro, 1 node), 1 Subnet Group, 1 Parameter Group
- **IAM**: 1 Role, 1 Instance Profile, 2 Policy Attachments, 1 Custom Policy
- **EC2**: 2 Instances (t2.micro)
  - Backend: Hyperswitch Router (port 8080) + Control Center (port 9000)
  - Frontend: SDK Server (port 9050)
- **Data Sources**: 3 (AZs, AMI, VPC)

## Setup Guide

### Prerequisites
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check Terraform version
terraform --version
```

### Required Variables
Configure in `terraform.tfvars`:
```hcl
aws_region    = "us-east-1"
stack_name    = "my-hyperswitch"
vpc_cidr      = "10.0.0.0/16"
db_password   = "secure_password_123"
admin_api_key = "admin_key_123"
```

### Deployment
```bash
# Navigate to environment
cd terraform/aws/environments/free-tier

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review deployment plan
terraform plan

# Deploy infrastructure (takes ~15 minutes)
terraform apply

# View service URLs
terraform output
```

### Access Your Applications
After deployment, access services via CloudFront URLs:

```bash
# Get all service URLs
terraform output

# Main application endpoints
terraform output api_url              # Router API
terraform output api_health_url       # Health check: /health
terraform output control_center_url   # Management dashboard
terraform output sdk_url              # SDK files and assets
terraform output sdk_loader_url       # Unified Checkout: HyperLoader.js

# Test API health
curl $(terraform output -raw api_health_url)
```

**Service Structure:**
- **Router API** (`api_url`): Payment processing endpoints at `/`
- **Control Center** (`control_center_url`): Management dashboard
- **SDK Server** (`sdk_url`): JavaScript SDK files and assets
- **Unified Checkout** (`sdk_loader_url`): HyperLoader.js for payment integration

### Cleanup
```bash
# Destroy all resources
terraform destroy
```

## Cost Estimate
- **Free Tier Resources**: EC2 (2 × t2.micro), RDS (db.t3.micro), ElastiCache (cache.t3.micro), ALB, CloudFront
- **Paid Resources**: NAT Gateway $33/month ($0.045/hour)
- **Lambda Functions**: $0/month (usage-based - free tier eligible)
- **Total**: $33/month during free tier period (after free tier: +$35/month for EC2)