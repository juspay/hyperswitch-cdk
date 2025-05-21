locals {
  // Determine which top-level stack to deploy based on variables
  is_hyperswitch_deployment   = var.deployment_type == "hyperswitch" && !var.deploy_locker_standalone && !var.deploy_imagebuilder_stack
  is_card_vault_deployment  = var.deployment_type == "card-vault" || var.deploy_locker_standalone
  is_imagebuilder_deployment = var.deployment_type == "imagebuilder" || var.deploy_imagebuilder_stack

  // Common tags to apply to all resources
  common_tags = merge(
    {
      "Project"     = "Hyperswitch",
      "Provisioner" = "Terraform"
    },
    var.tags
  )
}

#------------------------------------------------------------------------------
# VPC Module
# This will be the primary VPC for Hyperswitch or a new VPC for standalone Locker/ImageBuilder
#------------------------------------------------------------------------------
module "vpc" {
  source = "./modules/vpc"
  count  = local.is_hyperswitch_deployment || (local.is_card_vault_deployment && var.locker_standalone_vpc_id == null) || (local.is_imagebuilder_deployment) ? 1 : 0

  name             = var.vpc_name
  cidr_block       = var.vpc_cidr_block
  max_azs          = var.vpc_max_azs
  aws_region       = var.aws_region
  stack_prefix     = var.stack_prefix
  tags             = local.common_tags

  # Subnet configurations are based on lib/aws/networking.ts
  # VPC Configuration
  enable_nat_gateway = true
  single_nat_gateway = var.free_tier_deployment
  one_nat_gateway_per_az = !var.free_tier_deployment
  enable_dns_hostnames = true
  enable_dns_support = true

  # Specific named subnets from CDK (this needs more detailed mapping)
  # For now, these are illustrative placeholders.
  # We will create specific subnet resources in the vpc module later.
  enable_eks_worker_nodes_one_zone_subnets = local.is_hyperswitch_deployment && !var.free_tier_deployment
  enable_utils_zone_subnets                = local.is_hyperswitch_deployment && !var.free_tier_deployment
  enable_management_zone_subnets           = local.is_hyperswitch_deployment && !var.free_tier_deployment # Also for ImageBuilder
  enable_locker_database_zone_subnets      = local.is_hyperswitch_deployment || local.is_card_vault_deployment
  enable_service_layer_zone_subnets        = local.is_hyperswitch_deployment && !var.free_tier_deployment
  enable_data_stack_zone_subnets           = local.is_hyperswitch_deployment && !var.free_tier_deployment
  enable_external_incoming_zone_subnets    = local.is_hyperswitch_deployment && !var.free_tier_deployment # Also for ImageBuilder
  enable_database_zone_subnets             = local.is_hyperswitch_deployment # For main RDS
  enable_outgoing_proxy_lb_zone_subnets    = local.is_hyperswitch_deployment && !var.free_tier_deployment
  enable_outgoing_proxy_zone_subnets       = local.is_hyperswitch_deployment && !var.free_tier_deployment
  enable_locker_server_zone_subnets        = local.is_hyperswitch_deployment || local.is_card_vault_deployment
  enable_elasticache_zone_subnets          = local.is_hyperswitch_deployment
  enable_incoming_npci_zone_subnets        = local.is_hyperswitch_deployment && !var.free_tier_deployment
  enable_eks_control_plane_zone_subnets    = local.is_hyperswitch_deployment && !var.free_tier_deployment
  enable_incoming_web_envoy_zone_subnets   = local.is_hyperswitch_deployment && !var.free_tier_deployment
}

# Data source for EKS cluster authentication (needed by Helm and Kubernetes providers)
data "aws_eks_cluster_auth" "this" {
  count = local.is_hyperswitch_deployment && !var.free_tier_deployment ? 1 : 0
  name  = module.eks[0].cluster_id # Assuming EKS module is named 'eks' and outputs cluster_id
}

data "aws_caller_identity" "current" {}

#------------------------------------------------------------------------------
# IAM Module
#------------------------------------------------------------------------------
module "iam" {
  source = "./modules/iam"
  count  = 1 # IAM roles are generally always needed in some form

  stack_prefix                      = var.stack_prefix
  aws_region                        = var.aws_region
  aws_account_id                    = data.aws_caller_identity.current.account_id
  tags                              = local.common_tags
  eks_oidc_provider_arn             = local.is_hyperswitch_deployment && !var.free_tier_deployment ? module.eks[0].oidc_provider_arn : null
  eks_oidc_provider_url             = local.is_hyperswitch_deployment && !var.free_tier_deployment ? module.eks[0].oidc_provider_url : null

  create_image_builder_ec2_role     = local.is_imagebuilder_deployment
  create_eks_cluster_role           = local.is_hyperswitch_deployment && !var.free_tier_deployment # Added this line
  create_eks_nodegroup_role         = local.is_hyperswitch_deployment && !var.free_tier_deployment
  create_eks_service_account_roles  = local.is_hyperswitch_deployment && !var.free_tier_deployment
  hyperswitch_kms_key_arn           = local.is_hyperswitch_deployment && !var.free_tier_deployment ? module.kms_hyperswitch_app[0].key_arn : null # Corrected module name
  loki_s3_bucket_arn                = local.is_hyperswitch_deployment && !var.free_tier_deployment ? module.s3[0].loki_logs_bucket_arn : null # Corrected module name and output

  create_lambda_roles               = true # General lambda role often needed
  # lambda_secrets_manager_arns     = [module.secrets_rds[0].arn, module.secrets_locker_db[0].arn, module.secrets_locker_kms_data[0].arn] # Example
  # lambda_s3_bucket_arns_for_put   = [module.s3_rds_schema[0].bucket_arn, module.s3_locker_env[0].bucket_arn] # Example
  # lambda_kms_key_arns_for_usage   = [module.kms_locker[0].key_arn, module.kms_hyperswitch[0].key_arn] # Example

  create_codebuild_ecr_role         = local.is_hyperswitch_deployment && !var.free_tier_deployment
  # codebuild_project_arn_for_lambda_trigger = module.codebuild_ecr_transfer[0].project_arn # Example

  create_external_jump_ec2_role     = local.is_hyperswitch_deployment && !var.free_tier_deployment
  create_internal_jump_ec2_role     = local.is_hyperswitch_deployment && !var.free_tier_deployment # Added this line
  create_keymanager_ec2_role        = var.keymanager_enabled # Added this line
  external_jump_ssm_kms_key_arn     = local.is_hyperswitch_deployment && !var.free_tier_deployment ? module.kms_external_jump_ssm[0].key_arn : null # Corrected module name

  create_locker_ec2_role            = local.is_card_vault_deployment || (local.is_hyperswitch_deployment && var.locker_master_key != null) # If locker is part of hyperswitch
  locker_kms_key_arn_for_ec2_role   = module.kms_locker[0].key_arn # Example
  locker_env_bucket_arn_for_ec2_role= module.s3_locker_env[0].bucket_arn # Example

  create_envoy_ec2_role             = local.is_hyperswitch_deployment && !var.free_tier_deployment # Assuming Envoy is only for EKS
  envoy_proxy_config_bucket_arn     = module.s3_proxy_config[0].bucket_arn # Example

  create_squid_ec2_role             = local.is_hyperswitch_deployment && !var.free_tier_deployment # Assuming Squid is only for EKS
  squid_proxy_config_bucket_arn     = module.s3_proxy_config[0].bucket_arn # Example
  squid_logs_bucket_arn             = module.s3_squid_logs[0].bucket_arn # Example

  # Conditional dependencies for OIDC provider
  depends_on = [
    # module.eks # This creates a circular dependency if eks module needs iam roles.
    # OIDC provider should be created by EKS module, then passed to IAM.
  ]
}

#------------------------------------------------------------------------------
# S3 Buckets Module
#------------------------------------------------------------------------------
module "s3" {
  source = "./modules/s3"
  count  = 1 # Create S3 module, specific buckets within are conditional

  aws_account_id = data.aws_caller_identity.current.account_id
  aws_region     = var.aws_region
  stack_prefix   = var.stack_prefix
  tags           = local.common_tags

  create_rds_schema_bucket = local.is_hyperswitch_deployment && var.free_tier_deployment
  # rds_schema_bucket_name_suffix = "" # Default is fine

  create_locker_env_bucket                 = local.is_card_vault_deployment || (local.is_hyperswitch_deployment && var.locker_master_key != null)
  # locker_env_bucket_name_suffix          = "locker-env-store" # Default
  locker_kms_key_arn_for_bucket_encryption = module.kms_locker[0].key_arn # Assuming kms_locker module

  create_sdk_bucket        = local.is_hyperswitch_deployment && !var.free_tier_deployment
  # sdk_bucket_name_suffix = "sdk" # Default

  create_proxy_config_bucket        = local.is_hyperswitch_deployment && !var.free_tier_deployment # For Envoy and Squid configs
  # proxy_config_bucket_name_suffix = "proxy-config-bucket" # Default
  # envoy_config_content            = fileexists("path/to/envoy.yaml") ? file("path/to/envoy.yaml") : "" # Needs actual path or content
  # squid_config_files_path         = "./path/to/squid_configs" # Needs actual path

  create_squid_logs_bucket        = local.is_hyperswitch_deployment && !var.free_tier_deployment # If Squid is deployed
  # squid_logs_bucket_name_suffix = "outgoing-proxy-logs-bucket" # Default

  create_loki_logs_bucket        = local.is_hyperswitch_deployment && !var.free_tier_deployment # If Loki/Grafana is deployed
  # loki_logs_bucket_name_suffix = "hs-loki-logs-storage" # Default

  create_keymanager_env_bucket                 = var.keymanager_enabled
  keymanager_kms_key_arn_for_bucket_encryption = var.keymanager_enabled ? module.kms_keymanager[0].key_arn : null

  depends_on = [module.kms_locker, module.kms_keymanager] 
}

#------------------------------------------------------------------------------
# KMS Keys Module
#------------------------------------------------------------------------------
module "kms_locker" {
  source = "./modules/kms"
  count  = local.is_card_vault_deployment || (local.is_hyperswitch_deployment && var.locker_master_key != null) ? 1 : 0

  aws_account_id = data.aws_caller_identity.current.account_id
  key_alias_name = "alias/${var.stack_prefix}-locker-kms-key" # Matches CDK alias pattern
  description    = "KMS key for encrypting Locker data and S3 objects"
  # key_usage and key_spec defaults are fine (ENCRYPT_DECRYPT, SYMMETRIC_DEFAULT)
  # enable_key_rotation = true (CDK default for locker key)
  tags = local.common_tags
}

module "kms_hyperswitch_app" {
  source = "./modules/kms"
  count  = local.is_hyperswitch_deployment && !var.free_tier_deployment ? 1 : 0

  aws_account_id = data.aws_caller_identity.current.account_id
  key_alias_name = "alias/${var.stack_prefix}-kms-key" # Matches CDK alias "alias/hyperswitch-kms-key"
  description    = "KMS key for encrypting Hyperswitch application secrets"
  enable_key_rotation = false # CDK sets this to false for this key
  tags           = local.common_tags
}

module "kms_external_jump_ssm" {
  source = "./modules/kms"
  count  = local.is_hyperswitch_deployment && !var.free_tier_deployment ? 1 : 0

  aws_account_id = data.aws_caller_identity.current.account_id
  key_alias_name = "alias/${var.stack_prefix}-ssm-kms-key" # Matches CDK alias "alias/hyperswitch-ssm-kms-key"
  description    = "KMS key for encrypting SSM parameters for jump host"
  # enable_key_rotation = true (CDK default for this key)
  tags = local.common_tags
}

module "kms_keymanager" {
  source = "./modules/kms"
  count  = var.keymanager_enabled ? 1 : 0

  aws_account_id = data.aws_caller_identity.current.account_id
  key_alias_name = "alias/${var.stack_prefix}-km-${var.keymanager_name}-key" # Specific alias for this keymanager instance
  description    = "KMS key for Keymanager ${var.keymanager_name}"
  tags           = local.common_tags
}

#------------------------------------------------------------------------------
# Secrets Manager Module
#------------------------------------------------------------------------------
module "secrets" {
  source = "./modules/secretsmanager"
  count  = 1 # Create Secrets Manager module, specific secrets within are conditional

  stack_prefix = var.stack_prefix
  tags         = local.common_tags

  # RDS Master Secret (for main Hyperswitch DB)
  create_rds_master_secret     = local.is_hyperswitch_deployment
  rds_master_secret_name       = "${var.stack_prefix}-db-master-user-secret" # Aligns with CDK
  rds_db_name_for_secret       = var.rds_db_name
  rds_db_user_for_secret       = var.rds_db_user
  rds_db_password_for_secret   = var.db_password

  # Locker DB Master Secret
  create_locker_db_master_secret = local.is_card_vault_deployment || (local.is_hyperswitch_deployment && var.locker_master_key != null)
  locker_db_master_secret_name   = "${var.stack_prefix}-LockerDbMasterUserSecret" # Aligns with CDK
  locker_db_name_for_secret      = "locker"
  locker_db_user_for_secret      = var.locker_db_user
  locker_db_password_for_secret  = var.locker_db_password

  # Locker KMS Data Secret (for Lambda)
  create_locker_kms_data_secret    = local.is_card_vault_deployment || (local.is_hyperswitch_deployment && var.locker_master_key != null)
  locker_kms_data_secret_name      = "${var.stack_prefix}-LockerKmsDataSecret" # Aligns with CDK
  locker_kms_data_secret_content   = { # Populated by Locker module/logic later
    db_username = var.locker_db_user
    db_password = var.locker_db_password # This will be the plain text password
    # db_host     = module.locker_rds[0].cluster_endpoint # Example, from locker's RDS
    master_key  = var.locker_master_key
    # private_key = module.locker_rsa_keys[0].private_key_pem # Example
    # public_key  = module.locker_rsa_keys[0].tenant_public_key_pem # Example
    # kms_id      = module.kms_locker[0].key_id # Example
    region      = var.aws_region
  }

  # Hyperswitch EKS KMS Data Secret (for Lambda)
  create_hyperswitch_kms_data_secret = local.is_hyperswitch_deployment && !var.free_tier_deployment
  hyperswitch_kms_data_secret_name   = "${var.stack_prefix}-HyperswitchKmsDataSecret" # Aligns with CDK
  hyperswitch_kms_data_secret_content = { # Populated by EKS/Hyperswitch app logic later
    db_password        = var.db_password # Plain text
    jwt_secret         = "test_admin" # Default from CDK, should be a variable
    master_key         = var.master_encryption_key
    admin_api_key      = var.admin_api_key
    # kms_id             = module.kms_hyperswitch_app[0].key_id # Example
    region             = var.aws_region
    # locker_public_key  = (local.is_hyperswitch_deployment && var.locker_master_key != null) ? module.locker_rsa_keys[0].public_key_pem : "locker-key" # Example
    # tenant_private_key = (local.is_hyperswitch_deployment && var.locker_master_key != null) ? module.locker_rsa_keys[0].tenant_private_key_pem : "locker-key" # Example
  }

  # Keymanager Secrets
  create_keymanager_db_master_secret = var.keymanager_enabled
  keymanager_db_master_secret_name   = var.keymanager_enabled ? "${var.stack_prefix}-km-${var.keymanager_name}-DbMasterUserSecret" : null
  keymanager_db_name_for_secret      = var.keymanager_enabled ? "keymanager_${lower(replace(var.keymanager_name, " ", "_"))}" : null
  keymanager_db_user_for_secret      = var.keymanager_enabled ? var.keymanager_db_user : null
  keymanager_db_password_for_secret  = var.keymanager_enabled ? var.keymanager_db_pass : null

  create_keymanager_kms_data_secret    = var.keymanager_enabled
  keymanager_kms_data_secret_name      = var.keymanager_enabled ? "${var.stack_prefix}-km-${var.keymanager_name}-KmsDataSecret" : null
  keymanager_kms_data_secret_content   = var.keymanager_enabled ? {
    db_username     = var.keymanager_db_user
    db_password     = var.keymanager_db_pass # Plain text for Lambda to encrypt
    # db_host         = module.keymanager_stack[0].keymanager_rds_cluster_endpoint # This creates a circular dependency if KM stack needs this secret's ARN
    master_key      = var.keymanager_master_key_content
    keymanager_name = var.keymanager_name
    tls_key         = var.keymanager_tls_key_content
    tls_cert        = var.keymanager_tls_cert_content
    ca_cert         = var.keymanager_ca_cert_content
    kms_id          = module.kms_keymanager[0].key_id
    region          = var.aws_region
  } : {}

  recovery_window_in_days = 7 # Default from CDK
}

#------------------------------------------------------------------------------
# ElastiCache (Redis) Module
#------------------------------------------------------------------------------
module "elasticache" {
  source = "./modules/elasticache"
  count  = local.is_hyperswitch_deployment ? 1 : 0

  stack_prefix = var.stack_prefix
  vpc_id       = module.vpc[0].vpc_id
  # CDK uses publicSubnets. This is unusual. For now, using the 'elasticache_zone' if available,
  # otherwise falling back to a general public subnet list from the VPC module.
  # This needs careful review against actual network requirements.
  subnet_ids = length(module.vpc[0].elasticache_zone_subnet_ids) > 0 ? module.vpc[0].elasticache_zone_subnet_ids : module.vpc[0].public_subnet_ids # Or a specific private subnet group
  
  cluster_name        = "${var.stack_prefix}-hs-elasticache" # Matches CDK default pattern
  node_type           = "cache.t3.micro" # From CDK
  security_group_name = "${var.stack_prefix}-elasticache-SG" # Matches CDK
  tags                = local.common_tags

  depends_on = [module.vpc]
}

#------------------------------------------------------------------------------
# RDS Module (Main Hyperswitch Database)
#------------------------------------------------------------------------------
module "rds_hyperswitch" {
  source = "./modules/rds"
  count  = local.is_hyperswitch_deployment ? 1 : 0

  stack_prefix           = var.stack_prefix
  vpc_id                 = module.vpc[0].vpc_id
  database_zone_subnet_ids = module.vpc[0].database_zone_subnet_ids # Ensure these are private subnets from VPC module
  
  is_standalone_deployment = var.free_tier_deployment
  db_name                    = var.rds_db_name
  db_port                    = var.rds_port
  db_username                = var.rds_db_user
  master_user_secret_arn     = module.secrets[0].rds_master_secret_arn # From secrets module

  standalone_instance_type         = var.rds_standalone_instance_type
  # standalone_postgres_engine_version = "14" # Default in module

  aurora_writer_instance_type    = var.rds_writer_instance_type
  aurora_reader_instance_type    = var.rds_reader_instance_type
  aurora_reader_count            = var.free_tier_deployment ? 0 : 1 # No reader for free tier (standalone-like Aurora)
  # aurora_postgres_engine_version = "14.11" # Default in module
  
  security_group_name = "${var.stack_prefix}-db-SG" # Matches CDK
  tags                = local.common_tags

  # Schema Initialization for Standalone RDS
  create_schema_init_lambda_trigger = var.free_tier_deployment
  rds_schema_s3_bucket_name         = var.free_tier_deployment ? module.s3[0].rds_schema_bucket_id : null # ID is bucket name
  lambda_role_arn_for_schema_init   = var.free_tier_deployment ? module.iam[0].lambda_general_role_arn : null # General Lambda role
  isolated_subnet_ids_for_lambda    = var.free_tier_deployment ? module.vpc[0].private_isolated_subnet_ids : [] # Example, ensure these are correct for Lambda

  depends_on = [module.vpc, module.secrets, module.iam, module.s3]
}

#------------------------------------------------------------------------------
# EC2 Instances for Standalone Hyperswitch Deployment
#------------------------------------------------------------------------------
locals {
  # User data for App/CC EC2 instance
  userdata_app_cc = templatefile("${path.module}/templates/userdata_app_cc.sh.tpl", {
    redis_host    = module.elasticache[0].cluster_address
    db_host       = module.rds_hyperswitch[0].db_instance_address # Assuming standalone RDS for free_tier
    db_username   = var.rds_db_user
    db_password   = var.db_password # Passed directly to userdata
    db_name       = var.rds_db_name
    admin_api_key = var.admin_api_key
  })

  # User data for SDK/Demo EC2 instance - depends on the App/CC instance's private IP
  # This creates a dependency. We'll define sdk_demo_ec2 after app_cc_ec2.
}

module "ec2_app_cc_standalone" {
  source = "./modules/ec2"
  count  = local.is_hyperswitch_deployment && var.free_tier_deployment ? 1 : 0

  instance_name_prefix = "${var.stack_prefix}-app-cc-standalone"
  vpc_id                 = module.vpc[0].vpc_id
  subnet_ids             = module.vpc[0].public_subnet_ids # Deploys in public subnet as per CDK
  instance_type          = "t2.micro" # From CDK's get_standalone_ec2_config
  # ami_id                = null # Uses default Amazon Linux 2 from EC2 module
  user_data_base64       = base64encode(local.userdata_app_cc)
  associate_public_ip_address = true # Implied by CDK logic and outputs

  create_new_security_group = true
  security_group_name_prefix = "${var.stack_prefix}-app-cc-sg"
  security_group_ingress_rules = [
    { from_port = 80, to_port = 80, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "Allow HTTP for Hyperswitch Router" },
    { from_port = 9000, to_port = 9000, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "Allow HTTP for Control Center" },
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "Allow SSH" },
    # Note: CDK also adds an ingress from vpc.vpc.vpcCidrBlock on port 80 for SDK access.
    # This can be added if module.vpc[0].vpc_cidr_block is available and needed.
    # For now, keeping it simple as 0.0.0.0/0 covers it.
  ]
  tags = local.common_tags

  depends_on = [module.elasticache, module.rds_hyperswitch]
}

locals {
  # User data for SDK/Demo EC2 instance
  userdata_sdk_demo = local.is_hyperswitch_deployment && var.free_tier_deployment ? templatefile("${path.module}/templates/userdata_sdk_demo.sh.tpl", {
    app_cc_instance_public_ip  = module.ec2_app_cc_standalone[0].instance_public_ip
    app_cc_instance_private_ip = module.ec2_app_cc_standalone[0].instance_private_ip
    admin_api_key              = var.admin_api_key
    sdk_version                = "0.109.2" # From CDK userdata script
    sdk_sub_version            = "v0"      # From CDK userdata script
  }) : ""
}

module "ec2_sdk_demo_standalone" {
  source = "./modules/ec2"
  count  = local.is_hyperswitch_deployment && var.free_tier_deployment ? 1 : 0

  instance_name_prefix = "${var.stack_prefix}-sdk-demo-standalone"
  vpc_id                 = module.vpc[0].vpc_id
  subnet_ids             = module.vpc[0].public_subnet_ids # Deploys in public subnet
  instance_type          = "t2.micro" # From CDK's get_standalone_sdk_ec2_config
  user_data_base64       = base64encode(local.userdata_sdk_demo)
  associate_public_ip_address = true

  create_new_security_group = true
  security_group_name_prefix = "${var.stack_prefix}-sdk-demo-sg"
  security_group_ingress_rules = [
    { from_port = 9090, to_port = 9090, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "Allow HTTP for SDK assets" },
    { from_port = 5252, to_port = 5252, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "Allow HTTP for Demo App" },
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = ["0.0.0.0/0"], description = "Allow SSH" },
  ]
  tags = local.common_tags

  depends_on = [module.ec2_app_cc_standalone] # Depends on the app/cc instance for its IP
}

# Security Group rule: Allow SDK EC2 to access App CC EC2 on port 80
resource "aws_security_group_rule" "allow_sdk_to_app_cc" {
  count = local.is_hyperswitch_deployment && var.free_tier_deployment ? 1 : 0

  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = module.ec2_sdk_demo_standalone[0].security_group_id # SG of the SDK/Demo instance
  security_group_id        = module.ec2_app_cc_standalone[0].security_group_id # SG of the App/CC instance
  description              = "Allow SDK EC2 to access App CC EC2 router"
}


# Placeholder for Hyperswitch Stack (EKS or Standalone EC2)
module "eks" {
  source = "./modules/eks"
  count  = local.is_hyperswitch_deployment && !var.free_tier_deployment ? 1 : 0

  stack_prefix           = var.stack_prefix
  aws_region             = var.aws_region
  aws_account_id         = data.aws_caller_identity.current.account_id
  tags                   = local.common_tags
  vpc_id                 = module.vpc[0].vpc_id
  eks_control_plane_subnet_ids = module.vpc[0].eks_control_plane_zone_subnet_ids
  eks_worker_nodes_one_zone_subnet_ids = module.vpc[0].eks_worker_nodes_one_zone_subnet_ids
  utils_zone_subnet_ids    = module.vpc[0].utils_zone_subnet_ids
  service_layer_zone_subnet_ids = module.vpc[0].service_layer_zone_subnet_ids
  external_incoming_zone_subnet_ids = module.vpc[0].external_incoming_zone_subnet_ids
  
  public_access_cidrs    = var.eks_vpn_ips # From root var

  eks_cluster_role_arn   = module.iam[0].eks_cluster_role_arn
  eks_nodegroup_role_arn = module.iam[0].eks_nodegroup_role_arn
  eks_admin_arns         = compact(concat(var.eks_admin_aws_arn != null ? [var.eks_admin_aws_arn] : [], var.eks_additional_admin_aws_arn != null ? [var.eks_additional_admin_aws_arn] : []))


  hyperswitch_app_sa_role_arn = module.iam[0].eks_hyperswitch_service_account_role_arn
  grafana_loki_sa_role_arn    = module.iam[0].eks_grafana_loki_service_account_role_arn

  hyperswitch_app_kms_key_arn           = module.kms_hyperswitch_app[0].key_arn
  hyperswitch_app_secrets_manager_arn = module.secrets[0].hyperswitch_kms_data_secret_arn
  lambda_role_arn_for_kms_encryption  = module.iam[0].lambda_general_role_arn # General lambda role
  rds_db_password                     = var.db_password
  hyperswitch_master_enc_key          = var.master_encryption_key
  hyperswitch_admin_api_key           = var.admin_api_key
  # locker_public_key_pem will be tricky if card_vault_stack is conditional and not yet run
  # For now, assume it's available or a default is used if locker is not part of this EKS deployment.
  locker_public_key_pem  = local.is_card_vault_deployment ? module.card_vault_stack[0].locker_public_key_ssm_content : (var.locker_master_key != null ? "NEEDS_ACTUAL_LOCKER_PUBLIC_KEY" : "locker-key")
  tenant_private_key_pem = local.is_card_vault_deployment ? module.card_vault_stack[0].tenant_private_key_ssm_content : (var.locker_master_key != null ? "NEEDS_ACTUAL_TENANT_PRIVATE_KEY" : "locker-key")


  enable_ecr_image_transfer             = true # Default
  codebuild_ecr_role_arn                = module.iam[0].codebuild_ecr_role_arn
  lambda_role_arn_for_codebuild_trigger = module.iam[0].lambda_codebuild_trigger_role_arn

  sdk_s3_bucket_name    = module.s3[0].sdk_bucket_id # Bucket ID is the name
  sdk_s3_bucket_oai_arn = module.s3[0].sdk_oai_arn # Need to add OAI to S3 module output

  rds_cluster_endpoint        = module.rds_hyperswitch[0].aurora_cluster_endpoint # Assuming EKS always uses Aurora
  rds_cluster_reader_endpoint = module.rds_hyperswitch[0].aurora_cluster_reader_endpoint
  elasticache_cluster_address = module.elasticache[0].cluster_address

  keymanager_enabled_in_eks = var.keymanager_enabled # From root var
  keymanager_config_for_eks = var.keymanager_enabled ? {
    name     = var.keymanager_name
    db_user  = var.keymanager_db_user
    db_pass  = var.keymanager_db_pass
    tls_key  = var.keymanager_tls_key_content
    tls_cert = var.keymanager_tls_cert_content
    ca_cert  = var.keymanager_ca_cert_content
  } : null

  # Assuming AMIs are sourced from SSM parameters populated by Image Builder module
  envoy_ami_id = var.envoy_ami_ssm_parameter_name != "" ? data.aws_ssm_parameter.envoy_ami.value : null
  squid_ami_id = var.squid_ami_ssm_parameter_name != "" ? data.aws_ssm_parameter.squid_ami.value : null
  
  proxy_config_s3_bucket_name = module.s3[0].proxy_config_bucket_id
  squid_logs_s3_bucket_name   = module.s3[0].squid_logs_bucket_id
  # waf_arn_for_envoy_alb     = module.waf[0].web_acl_arn # Assuming a WAF module
  # For now, using the one created in EKS module if not provided externally
  waf_arn_for_envoy_alb = var.waf_web_acl_arn != null ? var.waf_web_acl_arn : (local.is_hyperswitch_deployment && !var.free_tier_deployment ? module.eks[0].waf_web_acl_arn_output : null)


  loki_s3_bucket_name = module.s3[0].loki_logs_bucket_id
  private_ecr_repository_prefix = "${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com"


  depends_on = [
    module.vpc, module.iam, module.s3, module.kms_hyperswitch_app, module.secrets,
    module.rds_hyperswitch, module.elasticache, 
    # module.image_builder_stack, # If AMIs are built in the same apply
    # module.card_vault_stack # If locker keys are needed and it's deployed
    module.keymanager_stack # If keymanager is deployed and its outputs are needed by EKS
  ]
}

module "keymanager_stack" {
  source = "./modules/keymanager"
  count  = var.keymanager_enabled ? 1 : 0 # Based on root variable

  stack_prefix = "${var.stack_prefix}-km-${var.keymanager_name}" # e.g. hyperswitch-km-HSBankofAmerica
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
  tags           = local.common_tags

  vpc_id = module.vpc[0].vpc_id # Assuming it deploys in the main VPC
  # These subnets need to be defined in the VPC module and outputted, or passed from existing VPC
  keymanager_database_subnet_ids   = module.vpc[0].data_stack_zone_subnet_ids # Example, use appropriate private subnets
  keymanager_server_subnet_ids     = module.vpc[0].service_layer_zone_subnet_ids # Example, use appropriate private subnets

  keymanager_name             = var.keymanager_name
  keymanager_db_user          = var.keymanager_db_user
  keymanager_db_password      = var.keymanager_db_pass # Renamed from keymanager_db_password for consistency
  keymanager_master_key       = var.keymanager_master_key_content # Renamed from keymanager_master_key
  keymanager_tls_key_content  = var.keymanager_tls_key_content
  keymanager_tls_cert_content = var.keymanager_tls_cert_content
  keymanager_ca_cert_content  = var.keymanager_ca_cert_content

  # IAM, KMS, S3, Secrets Manager dependencies - these need to be created specifically for Keymanager
  # or use outputs from existing common modules if appropriate.
  # For now, assuming dedicated resources are created or passed to the Keymanager module.
  # This requires adding specific KMS key, S3 bucket, Secrets for Keymanager in root or respective modules.
  keymanager_iam_instance_profile_name    = module.iam[0].keymanager_ec2_instance_profile_name # Needs to be added to IAM module
  keymanager_kms_key_arn                  = module.kms_keymanager[0].key_arn # Needs dedicated KMS key
  keymanager_env_s3_bucket_name           = module.s3[0].keymanager_env_bucket_id # Needs dedicated S3 bucket
  keymanager_secrets_manager_kms_data_arn = module.secrets[0].keymanager_kms_data_secret_arn # Needs dedicated Secret
  keymanager_db_secrets_manager_arn       = module.secrets[0].keymanager_db_master_secret_arn # Needs dedicated Secret
  lambda_role_arn_for_kms_encryption  = module.iam[0].lambda_general_role_arn # Can reuse general lambda role

  depends_on = [
    module.vpc, module.iam, 
    # module.kms_keymanager, module.s3_keymanager_env, module.secrets_keymanager
  ]
}

# --- EKS Jump Hosts ---
module "ec2_internal_jump" {
  source = "./modules/ec2"
  count  = local.is_hyperswitch_deployment && !var.free_tier_deployment ? 1 : 0

  instance_name_prefix        = "${var.stack_prefix}-internal-jump"
  vpc_id                      = module.vpc[0].vpc_id
  subnet_ids                  = module.vpc[0].management_zone_subnet_ids # Deploys in management zone (private)
  instance_type               = "t3.medium" # Default from CDK
  iam_instance_profile_name   = module.iam[0].internal_jump_ec2_instance_profile_name
  associate_public_ip_address = false # Internal jump host
  create_new_security_group   = true
  security_group_name_prefix  = "${var.stack_prefix}-internal-jump-sg"
  # Ingress for SSH typically from VPN or specific bastion/management network
  security_group_ingress_rules = [ 
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = var.eks_vpn_ips, description = "Allow SSH from VPN" }
  ]
  tags = local.common_tags
  depends_on = [module.vpc, module.iam]
}

module "ec2_external_jump" {
  source = "./modules/ec2"
  count  = local.is_hyperswitch_deployment && !var.free_tier_deployment ? 1 : 0

  instance_name_prefix        = "${var.stack_prefix}-external-jump"
  vpc_id                      = module.vpc[0].vpc_id
  subnet_ids                  = module.vpc[0].public_subnet_ids # Deploys in public subnet
  instance_type               = "t3.medium" # Default from CDK
  iam_instance_profile_name   = module.iam[0].external_jump_ec2_instance_profile_name
  associate_public_ip_address = true
  create_new_security_group   = true
  security_group_name_prefix  = "${var.stack_prefix}-external-jump-sg"
  security_group_ingress_rules = [
    { from_port = 22, to_port = 22, protocol = "tcp", cidr_blocks = var.eks_vpn_ips, description = "Allow SSH from VPN" }
  ]
  tags = local.common_tags
  depends_on = [module.vpc, module.iam]
}


# Data sources for AMIs if Image Builder is run separately or AMIs are pre-existing
data "aws_ssm_parameter" "envoy_ami" {
  count = var.envoy_ami_ssm_parameter_name != "" ? 1 : 0
  name  = var.envoy_ami_ssm_parameter_name
}
data "aws_ssm_parameter" "squid_ami" {
  count = var.squid_ami_ssm_parameter_name != "" ? 1 : 0
  name  = var.squid_ami_ssm_parameter_name
}


# module "hyperswitch_stack" {
#   count = local.is_hyperswitch_deployment ? 1 : 0
#   source = "./modules/hyperswitch"
#   # ... pass common vars and vpc outputs
# }

# Placeholder for Card Vault (Locker) Standalone Stack
module "card_vault_stack" {
  source = "./modules/card-vault"
  count  = local.is_card_vault_deployment ? 1 : 0

  stack_prefix = var.locker_standalone_stack_name # e.g., "tartarus"
  aws_region     = var.aws_region
  aws_account_id = data.aws_caller_identity.current.account_id
  tags           = local.common_tags

  vpc_id = var.locker_standalone_vpc_id == null ? module.vpc[0].vpc_id : var.locker_standalone_vpc_id
  
  # Ensure these subnet IDs are correctly populated from the VPC module or existing VPC.
  # These are specific to the Card Vault's needs.
  locker_database_zone_subnet_ids   = var.locker_standalone_vpc_id == null ? module.vpc[0].locker_database_zone_subnet_ids : [] # Provide if using existing VPC
  locker_server_zone_subnet_ids     = var.locker_standalone_vpc_id == null ? module.vpc[0].locker_server_zone_subnet_ids : []   # Provide if using existing VPC
  public_subnet_ids_for_jump_host = var.locker_standalone_vpc_id == null ? (length(module.vpc[0].public_subnet_ids) > 0 ? [module.vpc[0].public_subnet_ids[0]] : []) : [] # Provide if using existing VPC and jump host

  master_key_for_locker = var.locker_master_key # Must be provided
  db_user               = var.locker_db_user
  db_password           = var.locker_db_password # Must be provided

  locker_iam_instance_profile_name    = module.iam[0].locker_ec2_instance_profile_name
  locker_kms_key_arn                  = module.kms_locker[0].key_arn
  locker_env_s3_bucket_name           = module.s3[0].locker_env_bucket_id # Bucket ID is the name
  locker_secrets_manager_kms_data_arn = module.secrets[0].locker_kms_data_secret_arn
  locker_db_secrets_manager_arn       = module.secrets[0].locker_db_master_secret_arn
  lambda_role_arn_for_kms_encryption  = module.iam[0].lambda_general_role_arn # Using general lambda role

  enable_jump_host = var.enable_locker_jump_host

  depends_on = [
    module.vpc, # If creating new VPC for locker
    module.iam, 
    module.kms_locker, 
    module.s3, 
    module.secrets
  ]
}

# Placeholder for Image Builder Stack
module "image_builder_stack" {
  source = "./modules/image-builder"
  count  = local.is_imagebuilder_deployment ? 1 : 0

  stack_prefix                      = var.stack_prefix
  aws_region                        = var.aws_region
  aws_account_id                    = data.aws_caller_identity.current.account_id
  tags                              = local.common_tags
  base_ami_id                       = var.imagebuilder_base_ami_id # Pass this from root variables
  iam_instance_profile_name         = module.iam[0].image_builder_ec2_instance_profile_name
  vpc_id                            = module.vpc[0].vpc_id
  # Image builder needs a public subnet (or private with NAT/S3 endpoint for component downloads)
  # Using the first public subnet from the 'management_zone_subnet_ids' or default public subnets
  subnet_id_for_image_builder       = length(module.vpc[0].management_zone_subnet_ids) > 0 ? module.vpc[0].management_zone_subnet_ids[0] : module.vpc[0].public_subnet_ids[0]
  security_group_id_for_image_builder = module.ec2_image_builder_sg[0].id # Specific SG for image builder infra
  lambda_role_arn_for_triggers      = module.iam[0].lambda_general_role_arn # Using general lambda role

  # Component file paths are relative to the image-builder module
  # squid_component_file_path = "components/squid.yml" # Default in module
  # envoy_component_file_path = "components/envoy.yml" # Default in module
  # base_component_file_path  = "components/base.yml"  # Default in module

  squid_ami_ssm_parameter_name = var.squid_ami_ssm_parameter_name # Pass from root
  envoy_ami_ssm_parameter_name = var.envoy_ami_ssm_parameter_name # Pass from root
  base_ami_ssm_parameter_name  = var.base_ami_ssm_parameter_name  # Pass from root
  
  depends_on = [module.vpc, module.iam, module.ec2_image_builder_sg]
}

# Security Group for Image Builder Infrastructure (EC2 instances launched by Image Builder)
module "ec2_image_builder_sg" {
  source = "./modules/ec2" # Using the EC2 module to create a security group
  count  = local.is_imagebuilder_deployment ? 1 : 0

  instance_name_prefix = "${var.stack_prefix}-ib-infra" # Just for SG naming
  vpc_id                 = module.vpc[0].vpc_id
  
  create_new_security_group = true
  security_group_name_prefix = "${var.stack_prefix}-ib-infra-sg"
  security_group_allow_all_outbound = true
  # No ingress rules needed typically, as IB manages the instance.
  # If components need to download from specific internal sources, add egress here or ensure NAT/endpoints.

  # Set instance_type to a dummy value as we only need the SG from this module call
  instance_type = "t3.micro" 
  subnet_ids    = [module.vpc[0].public_subnet_ids[0]] # Dummy subnet_id
  # We are not creating an instance, just leveraging the SG creation part of the ec2 module.
  # This is a bit of a workaround. A dedicated SG module would be cleaner.
  # To prevent instance creation, we'd ideally have a flag in the ec2 module.
  # For now, this will create an SG. The instance won't be created if this module's output isn't used for an instance.
  # Better: Create aws_security_group directly here.
}

resource "aws_security_group" "image_builder_infra_sg" {
  count = local.is_imagebuilder_deployment ? 1 : 0
  name        = "${var.stack_prefix}-image-builder-infra-sg"
  description = "Security group for EC2 Image Builder infrastructure instances"
  vpc_id      = module.vpc[0].vpc_id
  tags        = local.common_tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Outputs
output "vpc_id" {
  description = "ID of the created VPC."
  value       = module.vpc[0].vpc_id
  sensitive   = false
}

# --- VPC Endpoints for EKS ---
resource "aws_vpc_endpoint" "s3_gateway" {
  count        = local.is_hyperswitch_deployment && !var.free_tier_deployment ? 1 : 0
  vpc_id       = module.vpc[0].vpc_id
  service_name = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids = concat(module.vpc[0].private_route_table_ids, module.vpc[0].public_route_table_ids, module.vpc[0].isolated_route_table_ids) # Attach to all route tables
  tags         = local.common_tags
}

locals {
  interface_endpoints_services = [
    "ec2", "ecr.api", "ecr.dkr", "sts", "secretsmanager", 
    "ssm", "ssmmessages", "ec2messages", "kms", "rds" 
    # "logs" # CDK adds this, but it's usually for CloudWatch Logs agent, not a direct VPC endpoint for EKS itself.
  ]
}

resource "aws_vpc_endpoint" "interface_endpoints" {
  for_each     = local.is_hyperswitch_deployment && !var.free_tier_deployment ? toset(local.interface_endpoints_services) : toset([])
  vpc_id       = module.vpc[0].vpc_id
  service_name = "com.amazonaws.${var.aws_region}.${each.key}"
  vpc_endpoint_type = "Interface"
  subnet_ids   = module.vpc[0].private_app_subnet_ids # Deploy endpoints in private subnets
  security_group_ids = [module.vpc[0].default_security_group_id] # Allow traffic from VPC
  private_dns_enabled = true
  tags         = merge(local.common_tags, { Name = "${var.stack_prefix}-vpce-${replace(each.key, ".", "-")}"})
}
