# CDK-TF Infrastructure as Code Project

This repository contains Terraform modules and configurations for deploying cloud infrastructure across multiple providers, with a primary focus on AWS services.

## 📋 Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Modules](#modules)
- [Environments](#environments)
- [Usage Examples](#usage-examples)
- [Contributing](#contributing)
- [License](#license)

## 🎯 Overview

This project provides a modular approach to infrastructure deployment using Terraform. It includes:

- **Multi-cloud support**: AWS, Azure, and GCP modules
- **Reusable modules**: For common infrastructure patterns
- **Environment-specific configurations**: Development, production, and specialized environments
- **Security-first approach**: Built-in security modules and best practices
- **Proxy and networking solutions**: Squid and Envoy proxy configurations

## 📁 Project Structure

```
.
├── environments/          # Environment-specific configurations
│   ├── aws/              # AWS environment configurations
│   │   ├── free-tier/    # Free tier compatible resources
│   │   ├── production/   # Production environment
│   │   ├── image-builder/# AMI building infrastructure
│   │   └── jump-servers/ # Bastion/Jump server setup
│   ├── azure/            # Azure environments (placeholder)
│   └── gcp/              # GCP environments (placeholder)
│
└── modules/              # Reusable Terraform modules
    ├── aws/              # AWS-specific modules
    │   ├── dockertoecr/  # Docker to ECR pipeline
    │   ├── eks/          # Elastic Kubernetes Service
    │   ├── elasticache/  # ElastiCache (Redis/Memcached)
    │   ├── envoy-proxy/  # Envoy proxy configuration
    │   ├── helm/         # Helm chart deployments
    │   ├── image-builder/# EC2 Image Builder
    │   ├── loadbalancers/# ALB/NLB/CloudFront
    │   ├── networking/   # VPC, Subnets, Routes
    │   ├── proxy/        # Proxy solutions
    │   ├── rds/          # RDS databases
    │   ├── sdk/          # SDK deployment infrastructure
    │   ├── security/     # Security components (IAM, WAF, etc.)
    │   └── squid-proxy/  # Squid proxy configuration
    ├── azure/            # Azure modules (to be implemented)
    └── gcp/              # GCP modules (to be implemented)
```

## 🔧 Prerequisites

- **Terraform**: >= 1.0.0
- **AWS CLI**: Configured with appropriate credentials
- **Git**: For version control
- **Python**: 3.8+ (for Lambda functions and automation scripts)

### Required AWS Permissions

Ensure your AWS credentials have permissions for:

- VPC and networking resources
- EC2 instances and Auto Scaling
- EKS clusters
- RDS databases
- ElastiCache clusters
- Lambda functions
- IAM roles and policies
- S3 buckets
- CloudFront distributions

## 🚀 Getting Started

1. **Clone the repository**

   ```bash
   git clone https://github.com/Shailesh-714/cdk-tf.git
   cd cdk-tf
   ```

2. **Choose an environment**

   ```bash
   cd environments/aws/free-tier  # or another environment
   ```

3. **Initialize Terraform**

   ```bash
   terraform init
   ```

4. **Review the configuration**

   - Update `terraform.tfvars` with your specific values
   - Review `variables.tf` for available options

5. **Plan the deployment**

   ```bash
   terraform plan
   ```

6. **Apply the configuration**
   ```bash
   terraform apply
   ```

## 📦 Modules

### AWS Modules

#### Core Infrastructure

- **networking**: VPC, subnets, route tables, and VPC endpoints
- **security**: IAM roles, policies, WAF rules, and encryption helpers
- **loadbalancers**: Application and Network Load Balancers, CloudFront

#### Compute

- **eks**: Managed Kubernetes clusters with IRSA support
- **image-builder**: Automated AMI creation pipelines
- **proxy**: Squid and Envoy proxy deployments

#### Data Services

- **rds**: Managed relational databases
- **elasticache**: Redis and Memcached clusters

#### CI/CD and Deployment

- **dockertoecr**: Docker image build and push to ECR
- **helm**: Helm chart deployments on EKS
- **sdk**: SDK deployment infrastructure

### Module Usage Example

```hcl
module "vpc" {
  source = "../../modules/aws/networking"

  vpc_cidr = "10.0.0.0/16"
  availability_zones = ["us-east-1a", "us-east-1b"]

  tags = {
    Environment = "production"
    Project     = "my-app"
  }
}

module "eks_cluster" {
  source = "../../modules/aws/eks"

  cluster_name = "my-eks-cluster"
  vpc_id       = module.vpc.vpc_id
  subnet_ids   = module.vpc.private_subnet_ids

  node_groups = {
    main = {
      desired_capacity = 3
      max_capacity     = 5
      min_capacity     = 1
      instance_types   = ["t3.medium"]
    }
  }
}
```

## 🌍 Environments

### AWS Environments

1. **free-tier**: Cost-optimized configuration using AWS free tier eligible resources
2. **production**: Production-ready configuration with high availability and security
3. **image-builder**: Dedicated environment for building custom AMIs
4. **jump-servers**: Bastion host configuration for secure access

### Environment Configuration

Each environment typically includes:

- `main.tf`: Main Terraform configuration
- `variables.tf`: Input variable definitions
- `terraform.tfvars`: Variable values (customize this)
- `outputs.tf`: Output values
- `backend.tf`: State storage configuration

## 💡 Usage Examples

### Deploy a Free Tier Environment

```bash
cd environments/aws/free-tier
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -auto-approve
```

### Create a Custom Module

1. Create a new directory under `modules/aws/`
2. Add the following files:
   - `main.tf`: Resource definitions
   - `variables.tf`: Input variables
   - `outputs.tf`: Output values
   - `README.md`: Module documentation

### Using Remote State

Configure remote state in `backend.tf`:

```hcl
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "environments/production/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Coding Standards

- Follow [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)
- Use meaningful resource names
- Add comments for complex logic
- Include README.md for each module
- Test modules in isolation before integration

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 📞 Support

For issues and questions:

- Create an issue in the [GitHub repository](https://github.com/Shailesh-714/cdk-tf/issues)
- Check existing documentation in module README files

## 🔒 Security

- Never commit sensitive data (passwords, API keys)
- Use AWS Secrets Manager or Parameter Store for secrets
- Follow the principle of least privilege for IAM roles
- Enable encryption at rest for all data stores
- Use VPC endpoints where possible to avoid internet traffic

---

**Note**: This project is under active development. Some modules may be incomplete or subject to change.
