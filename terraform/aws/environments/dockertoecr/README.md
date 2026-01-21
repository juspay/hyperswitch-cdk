# Docker to ECR Environment

## Description
Automated Docker image transfer system that pulls container images from external registries (Docker Hub, AWS Public ECR) and pushes them to a private AWS ECR registry. Used for creating private mirrors of required Hyperswitch and Kubernetes images.

## Resources Created (9 total)
- **CodeBuild**: 1 Project for image transfer operations
- **Lambda**: 1 Function to trigger builds, 1 Invocation
- **CloudWatch**: 1 Log Group for build logs
- **IAM**: 2 Roles, 2 Policies
- **Data Sources**: 3 (Region, Account ID, Lambda code archive)

## Images Transferred
- **Hyperswitch**: `juspaydotin/hyperswitch-router`, `hyperswitch-producer`, `hyperswitch-consumer`, `hyperswitch-drainer`, `hyperswitch-control-center`, `hyperswitch-web`
- **Grafana Stack**: `grafana/grafana`, `grafana/loki`, `grafana/promtail`, `grafana/fluent-bit-plugin-loki`
- **Kubernetes**: `nginx`, `bitnami/metrics-server`, `kiwigrid/k8s-sidecar`
- **Istio**: `istio/proxyv2`, `istio/pilot`
- **AWS EKS**: `eks/aws-load-balancer-controller`, `ebs-csi-driver/aws-ebs-csi-driver`

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
aws_region         = "us-east-1"
stack_name         = "hyperswitch-dockertoecr"
environment        = "dockertoecr"
log_retention_days = 30
```

### Deployment
```bash
# Navigate to environment
cd terraform/aws/environments/dockertoecr

# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Review deployment plan
terraform plan

# Deploy and trigger image transfer (takes ~20 minutes)
terraform apply

# Check build status
aws codebuild list-builds-for-project --project-name STACK_NAME-ecr-image-transfer
```

### Cleanup
```bash
# Destroy all resources (ECR repositories and images remain)
terraform destroy
```

## Cost Estimate
- **CodeBuild**: $0.005/minute (usage-based - only charged during builds)
- **Lambda**: $0/month (usage-based - free tier eligible, minimal invocations)
- **CloudWatch Logs**: $0.50/GB (usage-based)
- **ECR Storage**: $0.10/GB/month for stored images
- **Total**: $5-20/month (mostly ECR storage, minimal compute costs)