# General AWS Configuration
variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
  default     = "us-east-1"
}

variable "aws_profile" {
  description = "AWS CLI profile to use for authentication."
  type        = string
  default     = null # Uses default profile or instance role if null
}

variable "stack_prefix" {
  description = "A prefix for all resources created by this stack (e.g., 'hyperswitch')."
  type        = string
  default     = "hyperswitch"
}

variable "tags" {
  description = "A map of common tags to apply to all resources."
  type        = map(string)
  default     = {}
}

# Deployment Type Configuration
variable "deployment_type" {
  description = "Type of deployment: 'hyperswitch', 'card-vault', or 'imagebuilder'."
  type        = string
  default     = "hyperswitch"
  validation {
    condition     = contains(["hyperswitch", "card-vault", "imagebuilder"], var.deployment_type)
    error_message = "Invalid deployment_type. Must be one of: 'hyperswitch', 'card-vault', 'imagebuilder'."
  }
}

variable "free_tier_deployment" {
  description = "Set to true for a minimal standalone EC2-based Hyperswitch deployment (free tier eligible)."
  type        = bool
  default     = false
}

variable "deploy_locker_standalone" {
  description = "Set to true to deploy the Card Vault (Locker) as a standalone stack. Overrides deployment_type if true."
  type        = bool
  default     = false
}

variable "deploy_imagebuilder_stack" {
  description = "Set to true to deploy the EC2 Image Builder stack. Overrides deployment_type if true."
  type        = bool
  default     = false
}

# VPC Configuration
variable "vpc_name" {
  description = "Name for the VPC."
  type        = string
  default     = "hyperswitch-vpc"
}

variable "vpc_cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_max_azs" {
  description = "Maximum number of Availability Zones to use in the VPC."
  type        = number
  default     = 2 # Matches CDK default
}

# RDS Configuration (Main Hyperswitch Database)
variable "rds_db_name" {
  description = "Name for the main Hyperswitch RDS database."
  type        = string
  default     = "hyperswitch"
}

variable "rds_port" {
  description = "Port for the main Hyperswitch RDS database."
  type        = number
  default     = 5432
}

variable "rds_db_user" {
  description = "Username for the main Hyperswitch RDS database."
  type        = string
  default     = "dbadmin"
}

variable "db_password" { # Used for both main RDS and potentially EKS KmsDataSecret
  description = "Password for the main Hyperswitch RDS database. Also used for EKS secrets."
  type        = string
  sensitive   = true
  # No default, should be provided
}

variable "rds_standalone_instance_type" {
  description = "Instance type for the standalone RDS instance (free tier deployment)."
  type        = string
  default     = "db.t3.micro" # Matches CDK
}

variable "rds_writer_instance_type" {
  description = "Instance type for the Aurora RDS writer instance (EKS deployment)."
  type        = string
  default     = "db.r6g.large" # Matches CDK
}

variable "rds_reader_instance_type" {
  description = "Instance type for the Aurora RDS reader instances (EKS deployment)."
  type        = string
  default     = "db.r6g.large" # Matches CDK
}

# Hyperswitch Application Configuration (Standalone and EKS)
variable "admin_api_key" {
  description = "Admin API key for Hyperswitch."
  type        = string
  sensitive   = true
  # No default, should be provided
}

variable "master_encryption_key" { # Used for EKS KmsDataSecret
  description = "Master encryption key for Hyperswitch application."
  type        = string
  sensitive   = true
  # No default, should be provided
}

# EKS Specific Configuration
variable "eks_vpn_ips" {
  description = "List of CIDR blocks for VPN access to EKS public endpoint and jump hosts."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Default to allow all if not specified
}

variable "eks_admin_aws_arn" {
  description = "Primary AWS IAM User/Role ARN to grant EKS cluster admin access."
  type        = string
  default     = null # Optional
}

variable "eks_additional_admin_aws_arn" {
  description = "Additional AWS IAM User/Role ARN to grant EKS cluster admin access."
  type        = string
  default     = null # Optional
}

# Image Builder Configuration
variable "imagebuilder_base_ami_id" {
  description = "Optional: Base AMI ID for Image Builder. If null, latest Amazon Linux 2 is used."
  type        = string
  default     = null
}
variable "squid_ami_ssm_parameter_name" {
  description = "SSM parameter name to store/read Squid AMI ID."
  type        = string
  default     = "/hyperswitch/ami/squid"
}
variable "envoy_ami_ssm_parameter_name" {
  description = "SSM parameter name to store/read Envoy AMI ID."
  type        = string
  default     = "/hyperswitch/ami/envoy"
}
variable "base_ami_ssm_parameter_name" {
  description = "SSM parameter name to store/read Base AMI ID."
  type        = string
  default     = "/hyperswitch/ami/base"
}

# Card Vault (Locker) Standalone Configuration
variable "locker_standalone_stack_name" {
  description = "Stack name for the standalone Card Vault (Locker) deployment (e.g., 'tartarus')."
  type        = string
  default     = "tartarus"
}

variable "locker_standalone_vpc_id" {
  description = "Optional: Existing VPC ID to deploy the standalone Locker into. If null, a new VPC is created."
  type        = string
  default     = null
}

variable "locker_master_key" {
  description = "Master encryption key for the Locker application."
  type        = string
  sensitive   = true
  # No default, should be provided if deploying Locker
}

variable "locker_db_user" {
  description = "Database username for the Locker database."
  type        = string
  default     = "lockeradmin"
}

variable "locker_db_password" {
  description = "Database password for the Locker database."
  type        = string
  sensitive   = true
  # No default, should be provided if deploying Locker
}

variable "enable_locker_jump_host" {
  description = "Whether to create a jump host for the standalone Locker."
  type        = bool
  default     = true
}

# Keymanager Configuration (used if var.keymanager_enabled is true)
variable "keymanager_enabled" {
  description = "Set to true to deploy the Keymanager stack (either standalone or as part of EKS)."
  type        = bool
  default     = false
}

variable "keymanager_name" {
  description = "Name of the Keymanager instance (e.g., 'HSBankofAmerica'). Used for naming resources."
  type        = string
  default     = "DefaultKeyManager"
}

variable "keymanager_db_user" {
  description = "Database username for the Keymanager database."
  type        = string
  default     = "kmadmin"
}

variable "keymanager_db_pass" { # Changed from keymanager_db_password for consistency
  description = "Database password for the Keymanager database."
  type        = string
  sensitive   = true
  # No default, should be provided if keymanager_enabled is true
}

variable "keymanager_master_key_content" { # Changed from keymanager_master_key
  description = "Master encryption key content for the Keymanager application."
  type        = string
  sensitive   = true
  # No default, should be provided if keymanager_enabled is true
}

variable "keymanager_tls_key_content" {
  description = "TLS private key content (PEM format) for Keymanager."
  type        = string
  sensitive   = true
  # No default, should be provided if keymanager_enabled is true
}

variable "keymanager_tls_cert_content" {
  description = "TLS certificate content (PEM format) for Keymanager."
  type        = string
  # No default, should be provided if keymanager_enabled is true
}

variable "keymanager_ca_cert_content" {
  description = "CA certificate content (PEM format) for Keymanager."
  type        = string
  # No default, should be provided if keymanager_enabled is true
}

# WAF Configuration (Optional, for EKS Envoy ALB)
variable "waf_web_acl_arn" {
  description = "Optional: ARN of an existing WAF WebACL to associate with the EKS Envoy ALB. If null, a new basic WAF ACL is created by the EKS module."
  type        = string
  default     = null
}
