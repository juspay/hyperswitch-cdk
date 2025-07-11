terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

# Provider configurations
provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_availability_zones" "available" {
  state = "available"
}


data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Stack       = "Hyperswitch"
    StackName   = var.stack_name # Dynamic stack name per environment
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# External Jump Host
module "external_jump" {
  source = "./modules/jump-hosts/external"

  stack_name                 = var.stack_name
  vpc_id                     = var.vpc_id
  subnet_id                  = var.management_subnet_id
  vpc_cidr                   = var.vpc_cidr
  instance_type              = "t3.medium"
  kms_key_arn                = var.kms_key_arn
  enable_ssm_session_manager = true
  vpce_security_group_id     = var.vpce_security_group_id

  tags = var.common_tags
}

# Internal Jump Host
module "internal_jump" {
  source = "./modules/jump-hosts/internal"

  stack_name          = var.stack_name
  vpc_id              = var.vpc_id
  subnet_id           = var.utils_subnet_id
  vpc_cidr            = var.vpc_cidr
  instance_type       = "t3.medium"
  external_jump_sg_id = module.external_jump.security_group_id

  # Optional - connect to databases if they exist
  rds_sg_id         = var.rds_security_group_id
  elasticache_sg_id = var.elasticache_security_group_id
  locker_ec2_sg_id  = var.locker_ec2_security_group_id
  locker_db_sg_id   = var.locker_db_security_group_id

  tags = var.common_tags
}
