variable "stack_prefix" {
  description = "Prefix for stack resources (e.g., 'hyperswitch-km')."
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

variable "vpc_id" {
  description = "ID of the VPC where Keymanager will be deployed."
  type        = string
}

variable "keymanager_database_subnet_ids" {
  description = "List of subnet IDs for the Keymanager database."
  type        = list(string)
}

variable "keymanager_server_subnet_ids" {
  description = "List of subnet IDs for the Keymanager EC2 server."
  type        = list(string)
}

variable "keymanager_db_user" {
  description = "Database username for the Keymanager database."
  type        = string
}

variable "keymanager_db_password" {
  description = "Database password for the Keymanager database (plain text)."
  type        = string
  sensitive   = true
}

variable "keymanager_db_port" {
  description = "Port for the Keymanager RDS Aurora cluster."
  type        = number
  default     = 5432
}

variable "keymanager_aurora_instance_type" {
  description = "Instance type for the Keymanager Aurora DB cluster."
  type        = string
  default     = "db.t3.medium" # From CDK
}

variable "keymanager_aurora_engine_version" {
  description = "Aurora PostgreSQL engine version for Keymanager DB."
  type        = string
  default     = "13.7" # From CDK
}

variable "keymanager_ec2_instance_type" {
  description = "Instance type for the Keymanager EC2 server."
  type        = string
  default     = "t3.medium" # From CDK
}

variable "keymanager_ec2_ami_id" {
  description = "AMI ID for the Keymanager EC2 instance. If null, latest Amazon Linux 2 is used."
  type        = string
  default     = null
}

variable "keymanager_iam_instance_profile_name" {
  description = "Name of the IAM instance profile for the Keymanager EC2 instance."
  type        = string
}

variable "keymanager_kms_key_arn" {
  description = "ARN of the KMS key dedicated to Keymanager for S3 and Lambda data encryption."
  type        = string
}

variable "keymanager_env_s3_bucket_name" {
  description = "Name of the S3 bucket for storing Keymanager's encrypted environment file."
  type        = string
}

variable "keymanager_secrets_manager_kms_data_arn" {
  description = "ARN of the Secrets Manager secret that stores data for the Keymanager KMS encryption Lambda."
  type        = string
}

variable "keymanager_db_secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret for the Keymanager database credentials."
  type        = string
}

variable "lambda_role_arn_for_kms_encryption" {
  description = "ARN of the IAM role for the Lambda function that encrypts Keymanager secrets."
  type        = string
}

# Specific to Keymanager (from KeymanagerConfig in CDK)
variable "keymanager_name" {
  description = "Name of the Keymanager instance (e.g., 'HSBankofAmerica')."
  type        = string
}

variable "keymanager_tls_key_content" {
  description = "TLS private key content for Keymanager (PEM format)."
  type        = string
  sensitive   = true
}

variable "keymanager_tls_cert_content" {
  description = "TLS certificate content for Keymanager (PEM format)."
  type        = string
}

variable "keymanager_ca_cert_content" {
  description = "CA certificate content for Keymanager (PEM format)."
  type        = string
}

variable "keymanager_master_key" {
  description = "Master encryption key for the Keymanager application (plain text)."
  type        = string
  sensitive   = true
}
