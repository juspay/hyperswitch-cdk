# Jump Servers Environment

## Description
Secure two-tier bastion host architecture for safe access to private infrastructure. External jump server provides internet access, internal jump server accesses databases and internal services.

## Resources Created (20-32 total)
- **EC2**: 2 Instances (t3.medium) - external and internal jump servers with encrypted EBS (20GB gp3)
- **Security Groups**: 2 Security Groups, 2-10 Security Group Rules (depending on database access)
- **IAM**: 2 Roles, 1 Instance Profile each, 2-6 Policy Attachments
- **Data Sources**: 3 (AZs, Region, Caller Identity, optional AMI lookups)

## Modules Used (2 total)
- `external_jump` - Internet-facing bastion with Session Manager
- `internal_jump` - Private bastion for database access

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
# Basic Configuration
stack_name    = "hyperswitch-prod"
environment   = "production"

# Network Configuration (from existing VPC)
vpc_id                = "vpc-xxxxxxxxx"
vpc_cidr              = "10.0.0.0/16"
management_subnet_id  = "subnet-xxxxxxxxx"  # Public subnet
utils_subnet_id       = "subnet-xxxxxxxxx"  # Private subnet

# Security Configuration
kms_key_arn                = "arn:aws:kms:region:account:key/xxxxx"
vpce_security_group_id     = "sg-xxxxxxxxx"

# Optional - Database Access
rds_security_group_id         = "sg-xxxxxxxxx"
elasticache_security_group_id = "sg-xxxxxxxxx"
locker_ec2_security_group_id  = "sg-xxxxxxxxx"
locker_db_security_group_id   = "sg-xxxxxxxxx"
```

### Deployment
```bash
# Navigate to environment
cd terraform/aws/environments/jump-servers

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review deployment plan
terraform plan

# Deploy infrastructure (takes ~5 minutes)
terraform apply

# Connect via Session Manager
aws ssm start-session --target $(terraform output -raw external_jump_instance_id)
```

### Cleanup
```bash
# Destroy all resources
terraform destroy
```

## Cost Estimate
- **EC2 Instances**: 2 × t3.medium $61/month ($0.042/hour each)
- **EBS Storage**: 2 × 20GB gp3 $3/month ($0.08/GB/month)
- **Total**: $64/month