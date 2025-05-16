variable "stack_prefix" {
  description = "Prefix for stack resources (e.g., 'hyperswitch')."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "eks_oidc_provider_arn" {
  description = "OIDC provider ARN for the EKS cluster. Required if creating EKS service account roles."
  type        = string
  default     = null
}

variable "eks_oidc_provider_url" {
  description = "OIDC provider URL for the EKS cluster (without https://). Required if creating EKS service account roles."
  type        = string
  default     = null
}

// Variables for specific roles/policies based on CDK code

variable "create_image_builder_ec2_role" {
  description = "Whether to create the IAM role for EC2 Image Builder instances ('StationRole')."
  type        = bool
  default     = false
}

variable "create_eks_nodegroup_role" {
  description = "Whether to create the IAM role for EKS Node Groups ('HSNodegroupRole')."
  type        = bool
  default     = false
}

variable "create_eks_service_account_roles" {
  description = "Whether to create IAM roles for EKS service accounts (Hyperswitch App, Grafana/Loki)."
  type        = bool
  default     = false
}

variable "hyperswitch_kms_key_arn" {
  description = "ARN of the KMS key used by the Hyperswitch application in EKS for secrets."
  type        = string
  default     = null # Required if create_eks_service_account_roles is true for Hyperswitch app
}

variable "loki_s3_bucket_arn" {
  description = "ARN of the S3 bucket used by Loki for log storage."
  type        = string
  default     = null # Required if create_eks_service_account_roles is true for Grafana/Loki
}

variable "create_lambda_roles" {
  description = "Whether to create general IAM roles for Lambda functions (e.g., schema init, KMS encryption, Image Builder triggers)."
  type        = bool
  default     = false
}

variable "lambda_secrets_manager_arns" {
  description = "List of Secrets Manager ARNs that Lambda functions might need access to."
  type        = list(string)
  default     = []
}

variable "lambda_s3_bucket_arns_for_put" {
  description = "List of S3 bucket ARNs (and /* for objects) that Lambda functions might need PutObject access to."
  type        = list(string)
  default     = []
}

variable "lambda_kms_key_arns_for_usage" {
  description = "List of KMS Key ARNs that Lambda functions might need encrypt/decrypt access to."
  type        = list(string)
  default     = []
}

variable "create_codebuild_ecr_role" {
  description = "Whether to create the IAM role for CodeBuild ECR image transfer."
  type        = bool
  default     = false
}

variable "codebuild_project_arn_for_lambda_trigger" {
  description = "ARN of the CodeBuild project if creating a Lambda role to trigger it."
  type        = string
  default     = null
}

variable "create_external_jump_ec2_role" {
  description = "Whether to create the IAM role for the external jump EC2 instance."
  type        = bool
  default     = false
}

variable "external_jump_ssm_kms_key_arn" {
  description = "ARN of the KMS key for SSM session encryption for the external jump host."
  type        = string
  default     = null # Required if create_external_jump_ec2_role is true
}

variable "create_locker_ec2_role" {
  description = "Whether to create the IAM role for the Locker EC2 instance."
  type        = bool
  default     = false
}

variable "locker_kms_key_arn_for_ec2_role" {
  description = "ARN of the Locker's KMS key, for the Locker EC2 role."
  type        = string
  default     = null
}

variable "locker_env_bucket_arn_for_ec2_role" {
  description = "ARN of the Locker's environment S3 bucket, for the Locker EC2 role."
  type        = string
  default     = null
}

variable "create_envoy_ec2_role" {
  description = "Whether to create the IAM role for Envoy EC2 instances."
  type        = bool
  default     = false
}

variable "envoy_proxy_config_bucket_arn" {
  description = "ARN of the S3 bucket for Envoy proxy configuration."
  type        = string
  default     = null
}

variable "create_squid_ec2_role" {
  description = "Whether to create the IAM role for Squid EC2 instances."
  type        = bool
  default     = false
}

variable "squid_proxy_config_bucket_arn" {
  description = "ARN of the S3 bucket for Squid proxy configuration."
  type        = string
  default     = null
}

variable "squid_logs_bucket_arn" {
  description = "ARN of the S3 bucket for Squid logs."
  type        = string
  default     = null
}

variable "create_eks_cluster_role" {
  description = "Whether to create the IAM role for the EKS cluster itself."
  type        = bool
  default     = false
}

variable "create_internal_jump_ec2_role" {
  description = "Whether to create the IAM role for the EKS internal jump EC2 instance."
  type        = bool
  default     = false
}

variable "create_keymanager_ec2_role" {
  description = "Whether to create the IAM role for the Keymanager EC2 instance."
  type        = bool
  default     = false
}

variable "keymanager_kms_key_arn_for_ec2_role" {
  description = "ARN of the Keymanager's KMS key, for the Keymanager EC2 role."
  type        = string
  default     = null
}

variable "keymanager_env_bucket_arn_for_ec2_role" {
  description = "ARN of the Keymanager's environment S3 bucket, for the Keymanager EC2 role."
  type        = string
  default     = null
}
