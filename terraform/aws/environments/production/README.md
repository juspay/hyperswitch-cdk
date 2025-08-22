# Production Environment

## Description
Production-ready Hyperswitch deployment on AWS with EKS, Aurora PostgreSQL, ElastiCache Redis, and comprehensive security controls. High-availability setup across multiple AZs with service mesh, proxies, and autoscaling.

## Resources Created (~180-200 total)
- **VPC & Networking**: 1 VPC, 34 Subnets (across 2 AZs), 2 NAT Gateways, 2 EIPs, Route Tables, VPC Endpoints
- **EKS Cluster**: 1 EKS Cluster, 12 Node Groups, 4 EKS Addons (VPC CNI, CoreDNS, Kube Proxy, EBS CSI)
- **Database**: 1 Aurora PostgreSQL Cluster, 2 DB Instances (writer/reader), Subnet Group
- **Cache**: 1 ElastiCache Redis Cluster, Subnet Group
- **Load Balancers**: 1 Internal ALB, 1 NLB (Squid), Target Groups, Listeners
- **CloudFront**: 2 Distributions (Hyperswitch, SDK), 1 VPC Origin
- **Security**: WAF Web ACL, 2 KMS Keys, Secrets Manager, Security Groups, IAM Roles (~20+)
- **Proxies**: Squid Proxy ASG, Envoy Proxy ASG, Launch Templates, TLS Key Pairs
- **Applications**: 7 Helm Releases (ALB Controller, Istio, Hyperswitch, Metrics Server)
- **Storage**: 4 S3 Buckets (SDK, proxy config, logs, Helm logs)
- **Lambda & CodeBuild**: Build automation for SDK and applications

## Modules Used (12 total)
- `vpc` (networking)
- `security` (KMS, WAF, secrets)
- `rds` (Aurora PostgreSQL)
- `elasticache` (Redis)
- `loadbalancers` (ALB, CloudFront VPC origin)
- `eks` (Kubernetes cluster)
- `sdk` (SDK distribution)
- `proxy_config` (S3 proxy configs)
- `squid_proxy` (outbound proxy)
- `helm` (Kubernetes applications)
- `envoy_proxy` (ingress proxy)

## Setup Guide

### Prerequisites
```bash
# Verify AWS credentials and permissions
aws sts get-caller-identity

# Ensure you have required tools installed
terraform --version  # >= 1.12.2 required
kubectl version --client  # For EKS cluster management
helm version  # For application deployment
```

### Required Variables
Configure in `terraform.tfvars`:
```hcl
# Database
db_user            = "hyperswitch_user"
db_name            = "hyperswitch_db"
db_password        = "secure_password_123"

# Security Keys (generate strong values)
jwt_secret         = "jwt_secret_key"
master_key         = "your_64_char_hex_key"  # 64 character hexadecimal key
admin_api_key      = "admin_api_key_123"
locker_public_key  = "locker_public_key"
tenant_private_key = "tenant_private_key"

# AMI IDs (from image-builder environment)
envoy_image_ami    = "ami-xxxxxxxxx"
squid_image_ami    = "ami-xxxxxxxxx"

# Network Access
vpn_ips = ["YOUR.OFFICE.IP/32"]
```

### Generate Master Encryption Key
```bash
# Generate the AES master encryption key (64 character hexadecimal)
openssl enc -aes-256-cbc -k secret -P -md sha1
# Copy the 'key' value from the output and use it as master_key
```

### Deployment
```bash
# Navigate to environment
cd terraform/aws/environments/production

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review deployment plan
terraform plan

# Deploy infrastructure (takes ~45 minutes)
terraform apply

# Configure kubectl
aws eks update-kubeconfig --region REGION --name STACK_NAME-eks-cluster

# View outputs
terraform output
```

### Access Your Applications
After deployment, access services via CloudFront URLs:

```bash
# Get all service URLs
terraform output

# Main application endpoints
terraform output hyperswitch_cloudfront_distribution_domain_name  # Main CloudFront domain
terraform output sdk_distribution_domain_name                     # SDK CloudFront domain

# Application structure
# https://YOUR_CLOUDFRONT_DOMAIN/          -> Control Center (Dashboard)
# https://YOUR_CLOUDFRONT_DOMAIN/api       -> Router API
# https://YOUR_CLOUDFRONT_DOMAIN/api/health -> Health check
# https://SDK_CLOUDFRONT_DOMAIN/web/<sdk-version>/<sdk-subversion>/HyperLoader.js -> Unified Checkout

# Test API health
curl https://$(terraform output -raw hyperswitch_cloudfront_distribution_domain_name)/api/health
```

**Service Structure:**
- **Control Center**: `https://YOUR_CLOUDFRONT_DOMAIN/` - Management dashboard
- **Router API**: `https://YOUR_CLOUDFRONT_DOMAIN/api` - Payment processing endpoints
- **Health Check**: `https://YOUR_CLOUDFRONT_DOMAIN/api/health` - Application status
- **Unified Checkout**: `https://SDK_CLOUDFRONT_DOMAIN/web/<sdk-version>/<sdk-subversion>/HyperLoader.js` - HyperLoader.js

### Cleanup
```bash
# Destroy all resources
terraform destroy
```

## Cost Estimate
- **EKS Cluster**: $73/month ($0.10/hour)
- **Aurora PostgreSQL**: $85-170/month (db.r6g.large writer + reader)
- **ElastiCache Redis**: $45-90/month (cache.r6g.large)
- **NAT Gateways**: $90/month ($0.045/hour × 2 AZs)
- **EC2 Instances**: $150-400/month (EKS nodes, proxy ASGs)
- **Application Load Balancer**: $18/month ($0.025/hour)
- **Network Load Balancer**: $18/month ($0.025/hour)
- **CloudFront**: $1-10/month (usage-based)
- **Lambda Functions**: $0-5/month (usage-based - charged per invocation/duration)
- **CodeBuild**: $0-10/month (usage-based - charged per build minute)
- **S3 Storage**: $1-5/month (depending on stored data)
- **Total**: $480-880/month depending on usage and scaling
