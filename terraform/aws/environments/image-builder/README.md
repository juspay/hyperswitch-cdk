# Image Builder Environment

## Description
AWS Image Builder environment for creating custom AMIs with pre-installed security, proxy, and database components. Builds three types of standardized images for Hyperswitch infrastructure deployment.

## Resources Created (46 total)
- **VPC & Networking**: 1 VPC, 1 Internet Gateway, 2 Public Subnets, 1 Route Table, 2 Route Table Associations, 1 Security Group
- **Image Builder**: 3 Components, 3 Image Recipes, 3 Infrastructure Configurations, 3 Image Pipelines
- **SNS**: 3 Topics, 3 Subscriptions
- **Lambda**: 4 Functions, 1 Invocation, 3 Permissions
- **IAM**: 1 Role, 3 Instance Profiles, 2 Policy Attachments, 1 Lambda Role, 1 Lambda Policy
- **Data Sources**: 6 (AMI, AZs, Region, Account ID, 2 Archive files)

## AMI Types Built (3 total)

### Base Image
- **Wazuh Agent**: Security monitoring 
- **Redis 6**: In-memory data store
- **PostgreSQL 15**: Database with initialized data directory
- **ClamAV 1.4.2**: Antivirus engine
- **System Updates**: Latest security patches

### Envoy Image  
- **Wazuh Agent**: Security monitoring
- **Envoy Proxy 1.34.0**: High-performance load balancer/proxy
- **Network Capabilities**: Privileged port binding
- **Systemd Service**: Auto-start configuration

### Squid Image
- **Wazuh Agent**: Security monitoring  
- **Vector 0.47.0**: Log shipping and processing
- **Squid Proxy**: Web proxy with SSL capabilities
- **SSL Configuration**: Self-signed certificates and SSL database

## Setup Guide

### Prerequisites
```bash
# Verify AWS credentials
aws sts get-caller-identity

# Check Terraform version
terraform --version
```

### Optional Variables
Configure in `terraform.tfvars` (all have defaults):
```hcl
aws_region = "us-east-1"
stack_name = "hyperswitch" 
vpc_cidr   = "10.0.0.0/16"
ami_id     = null        # Uses latest Amazon Linux 2023
az_count   = 2
```

### Deployment
```bash
# Navigate to environment
cd terraform/aws/environments/image-builder

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review deployment plan
terraform plan

# Deploy and start image builds (takes ~60 minutes total)
terraform apply

# Monitor build progress
aws imagebuilder list-image-build-versions --image-arn $(aws imagebuilder list-images --query 'imageVersionList[0].arn' --output text)
```

### Cleanup
```bash
# Destroy infrastructure (built AMIs remain available)
terraform destroy
```

## Cost Estimate
- **EC2 Build Instances**: $0.042/hour during builds (usage-based - t3.medium)
- **Build Time**: ~20 minutes per AMI (3 AMIs = 1 hour total)
- **AMI Storage**: $0.023/GB/month for stored AMIs
- **Lambda**: $0/month (usage-based - free tier eligible, minimal invocations)
- **SNS**: $0/month (usage-based - free tier eligible)
- **CloudWatch Logs**: $0.50/GB (usage-based)
- **Total**: $2-8 per build cycle (mostly storage costs after initial build)