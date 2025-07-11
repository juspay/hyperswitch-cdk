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
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.37.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
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

  # Determine if the environment is production
  is_production = true

  # VPC CIDR configuration
  vpc_cidr = var.vpc_cidr

  # Availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

  # Private ECR repository for EKS
  private_ecr_repository = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_region.current.name}.amazonaws.com"

  # SDK version
  sdk_version = "0.121.2"
}

# VPC configuration
module "vpc" {
  source = "../../../modules/aws/networking"

  vpc_cidr             = local.vpc_cidr
  availability_zones   = slice(local.azs, 0, 2)
  stack_name           = var.stack_name
  common_tags          = local.common_tags
  enable_nat_gateway   = true
  single_nat_gateway   = !local.is_production
  enable_dns_hostnames = true
  enable_dns_support   = true
}

module "security" {
  source = "../../../modules/aws/security"

  stack_name    = var.stack_name
  common_tags   = local.common_tags
  is_production = local.is_production
  vpc_id        = module.vpc.vpc_id
  vpc_cidr      = local.vpc_cidr
  vpn_ips       = var.vpn_ips

  db_user            = var.db_user
  db_name            = var.db_name
  db_password        = var.db_password
  jwt_secret         = var.jwt_secret
  master_key         = var.master_key
  admin_api_key      = var.admin_api_key
  locker_public_key  = var.locker_public_key
  tenant_private_key = var.tenant_private_key
}

module "rds" {
  source = "../../../modules/aws/rds"

  stack_name  = var.stack_name
  common_tags = local.common_tags
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.subnet_ids
  db_user     = var.db_user
  db_name     = var.db_name
  db_password = var.db_password
  db_port     = var.db_port
}

module "elasticache" {
  source = "../../../modules/aws/elasticache"

  stack_name  = var.stack_name
  common_tags = local.common_tags
  vpc_id      = module.vpc.vpc_id
  subnet_ids  = module.vpc.subnet_ids
}

module "dockertoecr" {
  source = "../../../modules/aws/dockertoecr"

  stack_name         = var.stack_name
  common_tags        = local.common_tags
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.subnet_ids
  log_retention_days = var.log_retention_days
}

module "loadbalancers" {
  source = "../../../modules/aws/loadbalancers"

  stack_name      = var.stack_name
  common_tags     = local.common_tags
  vpc_id          = module.vpc.vpc_id
  subnet_ids      = module.vpc.subnet_ids
  vpn_ips         = var.vpn_ips
  waf_web_acl_arn = module.security.waf_web_acl_arn
  # vpc_endpoints_security_group_id = module.security.vpc_endpoints_security_group_id
}

module "sdk" {
  source = "../../../modules/aws/sdk"

  stack_name                            = var.stack_name
  common_tags                           = local.common_tags
  vpc_id                                = module.vpc.vpc_id
  subnet_ids                            = module.vpc.subnet_ids
  sdk_version                           = local.sdk_version
  external_alb_distribution_domain_name = module.loadbalancers.external_alb_distribution_domain_name
  log_retention_days                    = var.log_retention_days
}

module "eks" {
  source = "../../../modules/aws/eks"

  stack_name                    = var.stack_name
  common_tags                   = local.common_tags
  vpc_id                        = module.vpc.vpc_id
  vpc_cidr                      = local.vpc_cidr
  subnet_ids                    = module.vpc.subnet_ids
  private_subnet_ids            = module.vpc.eks_worker_nodes_subnet_ids
  control_plane_subnet_ids      = module.vpc.eks_control_plane_zone_subnet_ids
  kubernetes_version            = var.kubernetes_version
  vpn_ips                       = var.vpn_ips
  kms_key_arn                   = module.security.hyperswitch_kms_key_arn
  log_retention_days            = var.log_retention_days
  rds_security_group_id         = module.rds.rds_security_group_id
  elasticache_security_group_id = module.elasticache.elasticache_security_group_id
}

# Proxy Configuration S3 Bucket (shared between Envoy and Squid)
module "proxy_config" {
  source = "../../../modules/aws/proxy-config"

  stack_name  = var.stack_name
  common_tags = local.common_tags
  vpc_id      = module.vpc.vpc_id
}

# Squid Proxy Module (Comment out if not needed)
module "squid_proxy" {
  source = "../../../modules/aws/squid-proxy"

  stack_name                    = var.stack_name
  common_tags                   = local.common_tags
  vpc_id                        = module.vpc.vpc_id
  subnet_ids                    = module.vpc.subnet_ids
  squid_image_ami               = var.squid_image_ami
  eks_cluster_security_group_id = module.eks.eks_cluster_security_group_id
  proxy_config_bucket_name      = module.proxy_config.proxy_config_bucket_name
  proxy_config_bucket_arn       = module.proxy_config.proxy_config_bucket_arn
}

module "helm" {
  source = "../../../modules/aws/helm"

  stack_name                            = var.stack_name
  common_tags                           = local.common_tags
  vpc_id                                = module.vpc.vpc_id
  subnet_ids                            = module.vpc.subnet_ids
  vpn_ips                               = var.vpn_ips
  sdk_version                           = local.sdk_version
  private_ecr_repository                = local.private_ecr_repository
  eks_cluster_name                      = module.eks.eks_cluster_name
  eks_cluster_endpoint                  = module.eks.eks_cluster_endpoint
  eks_cluster_ca_certificate            = module.eks.eks_cluster_ca_certificate
  eks_cluster_security_group_id         = module.eks.eks_cluster_security_group_id
  alb_controller_role_arn               = module.eks.alb_controller_role_arn
  hyperswitch_kms_key_id                = module.security.hyperswitch_kms_key_id
  hyperswitch_service_account_role_arn  = module.eks.hyperswitch_service_account_role_arn
  istio_service_account_role_arn        = module.eks.istio_service_account_role_arn
  grafana_service_account_role_arn      = module.eks.grafana_service_account_role_arn
  kms_secrets                           = module.security.kms_secrets
  locker_enabled                        = var.locker_enabled
  locker_public_key                     = var.locker_public_key
  tenant_private_key                    = var.tenant_private_key
  db_password                           = var.db_password
  rds_cluster_endpoint                  = module.rds.rds_cluster_endpoint
  rds_cluster_reader_endpoint           = module.rds.rds_cluster_reader_endpoint
  elasticache_cluster_endpoint_address  = module.elasticache.elasticache_cluster_endpoint_address
  sdk_distribution_domain_name          = module.sdk.sdk_distribution_domain_name
  external_alb_distribution_domain_name = module.loadbalancers.external_alb_distribution_domain_name
  squid_nlb_dns_name                    = module.squid_proxy.squid_nlb_dns_name
}

# Envoy Proxy Module
module "envoy_proxy" {
  source = "../../../modules/aws/envoy-proxy"

  stack_name                            = var.stack_name
  common_tags                           = local.common_tags
  vpc_id                                = module.vpc.vpc_id
  subnet_ids                            = module.vpc.subnet_ids
  envoy_image_ami                       = var.envoy_image_ami
  internal_alb_security_group_id        = module.helm.internal_alb_security_group_id
  external_alb_security_group_id        = module.loadbalancers.external_alb_security_group_id
  internal_alb_domain_name              = module.helm.internal_alb_dns_name
  external_alb_distribution_domain_name = module.loadbalancers.external_alb_distribution_domain_name
  envoy_target_group_arn                = module.loadbalancers.envoy_target_group_arn
  proxy_config_bucket_name              = module.proxy_config.proxy_config_bucket_name
  proxy_config_bucket_arn               = module.proxy_config.proxy_config_bucket_arn
}

