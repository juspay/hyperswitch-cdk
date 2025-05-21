# Hyperswitch Terraform Infrastructure

This repository contains the Terraform configurations for deploying Hyperswitch infrastructure. It provides a modular and scalable approach to manage cloud resources across different environments.

## Architecture Overview

The infrastructure is organized into the following modules:

- `vpc`: Network configuration and subnets
- `eks`: Kubernetes cluster setup
- `rds`: Database configuration
- `elasticache`: Redis cache setup
- `card-vault`: Card vault service deployment
- `keymanager`: Key management service
- `iam`: Identity and access management
- `s3`: Object storage configuration
- `secretsmanager`: Secrets management
- `ec2`: EC2 instance management

## Prerequisites

- Terraform >= 1.0
- AWS CLI configured with appropriate credentials
- AWS account with necessary permissions

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Review the plan:
   ```bash
   terraform plan
   ```

3. Apply the configuration:
   ```bash
   terraform apply
   ```

## Configuration

The infrastructure can be customized through variables defined in `variables.tf`. Key configurations include:

- Deployment type (hyperswitch, card-vault, imagebuilder)
- VPC and subnet configurations
- Instance types and sizes
- Database configurations
- Security group rules

## Security Considerations

- All sensitive data is managed through AWS Secrets Manager
- Network access is controlled through security groups
- IAM roles follow the principle of least privilege
- KMS encryption for sensitive data

## Best Practices

- Use workspaces for managing different environments
- Follow tagging standards for resource management
- Regularly update provider and module versions
- Implement proper state management
- Use variables for environment-specific configurations

## Contributing

Please follow the standard pull request process and ensure all changes are properly tested.