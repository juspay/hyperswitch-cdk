variable "aws_account_id" {
  description = "AWS Account ID."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
}

variable "stack_prefix" {
  description = "Prefix for stack resources (e.g., 'hyperswitch')."
  type        = string
  default     = "hyperswitch"
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "create_rds_schema_bucket" {
  description = "Whether to create the S3 bucket for RDS standalone schema initialization."
  type        = bool
  default     = false
}

variable "rds_schema_bucket_name_suffix" {
  description = "Suffix for the RDS schema bucket name (appended to stack_prefix-schema-accountid-region)."
  type        = string
  default     = "" # CDK uses "hyperswitch-schema-${cdk.Aws.ACCOUNT_ID}-${process.env.CDK_DEFAULT_REGION}"
}

variable "create_locker_env_bucket" {
  description = "Whether to create the S3 bucket for the Locker environment file."
  type        = bool
  default     = false
}

variable "locker_env_bucket_name_suffix" {
  description = "Suffix for the Locker env bucket name."
  type        = string
  default     = "locker-env-store" # CDK uses "locker-env-store-${cdk.Aws.ACCOUNT_ID}-${process.env.CDK_DEFAULT_REGION}"
}

variable "locker_kms_key_arn_for_bucket_encryption" {
  description = "KMS Key ARN for encrypting the Locker environment bucket. Required if create_locker_env_bucket is true."
  type        = string
  default     = null
}

variable "create_sdk_bucket" {
  description = "Whether to create the S3 bucket for Hyperswitch SDK assets."
  type        = bool
  default     = false
}

variable "sdk_bucket_name_suffix" {
  description = "Suffix for the SDK bucket name."
  type        = string
  default     = "sdk" # CDK uses "hyperswitch-sdk-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}"
}

variable "create_proxy_config_bucket" {
  description = "Whether to create the S3 bucket for proxy configurations (Envoy, Squid)."
  type        = bool
  default     = false
}

variable "proxy_config_bucket_name_suffix" {
  description = "Suffix for the proxy config bucket name."
  type        = string
  default     = "proxy-config-bucket" # CDK uses "proxy-config-bucket-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}"
}

variable "create_squid_logs_bucket" {
  description = "Whether to create the S3 bucket for Squid proxy logs."
  type        = bool
  default     = false
}

variable "squid_logs_bucket_name_suffix" {
  description = "Suffix for the Squid logs bucket name."
  type        = string
  default     = "outgoing-proxy-logs-bucket" # CDK uses "outgoing-proxy-logs-bucket-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}"
}

variable "create_loki_logs_bucket" {
  description = "Whether to create the S3 bucket for Loki log storage."
  type        = bool
  default     = false
}

variable "loki_logs_bucket_name_suffix" {
  description = "Suffix for the Loki logs bucket name."
  type        = string
  default     = "hs-loki-logs-storage" # CDK uses "hs-loki-logs-storage-${process.env.CDK_DEFAULT_ACCOUNT}-${process.env.CDK_DEFAULT_REGION}"
}

variable "create_keymanager_env_bucket" {
  description = "Whether to create the S3 bucket for the Keymanager environment file."
  type        = bool
  default     = false
}

variable "keymanager_env_bucket_name_suffix" {
  description = "Suffix for the Keymanager env bucket name."
  type        = string
  default     = "keymanager-env-store" 
}

variable "keymanager_kms_key_arn_for_bucket_encryption" {
  description = "KMS Key ARN for encrypting the Keymanager environment bucket. Required if create_keymanager_env_bucket is true."
  type        = string
  default     = null
}

variable "envoy_config_content" {
  description = "Content for the envoy.yaml file to be uploaded to the proxy_config bucket."
  type        = string
  default     = ""
}

variable "squid_config_files_path" {
  description = "Path to the directory containing Squid configuration files to upload."
  type        = string
  default     = "" # e.g., "./squid_configs" which would contain squid.conf, blacklist.txt etc.
}
