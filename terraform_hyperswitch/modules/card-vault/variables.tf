variable "stack_prefix" {
  description = "Prefix for stack resources (e.g., 'hyperswitch' or 'tartarus')."
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
  description = "ID of the VPC where the Card Vault (Locker) will be deployed."
  type        = string
}

variable "locker_database_zone_subnet_ids" {
  description = "List of subnet IDs for the Locker database (PRIVATE_ISOLATED)."
  type        = list(string)
}

variable "locker_server_zone_subnet_ids" {
  description = "List of subnet IDs for the Locker EC2 server (PRIVATE_ISOLATED)."
  type        = list(string)
}

variable "public_subnet_ids_for_jump_host" { # For the optional jump host
  description = "List of public subnet IDs to deploy the jump host into."
  type        = list(string)
  default     = []
}

variable "master_key_for_locker" {
  description = "Master encryption key for the Locker application (plain text, will be encrypted by Lambda)."
  type        = string
  sensitive   = true
}

variable "db_user" {
  description = "Database username for the Locker database."
  type        = string
}

variable "db_password" {
  description = "Database password for the Locker database (plain text)."
  type        = string
  sensitive   = true
}

variable "db_port" {
  description = "Port for the Locker RDS Aurora cluster."
  type        = number
  default     = 5432
}

variable "aurora_instance_type" {
  description = "Instance type for the Locker Aurora DB cluster (e.g., 'db.t4g.medium')."
  type        = string
  default     = "db.t4g.medium" # From CDK
}

variable "aurora_engine_version" {
  description = "Aurora PostgreSQL engine version for Locker DB."
  type        = string
  default     = "13.7" # From CDK
}

variable "locker_ec2_instance_type" {
  description = "Instance type for the Locker EC2 server."
  type        = string
  default     = "t3.medium" # From CDK
}

variable "locker_ec2_ami_id" {
  description = "AMI ID for the Locker EC2 instance. If null, latest Amazon Linux 2 is used."
  type        = string
  default     = null
}

variable "locker_iam_instance_profile_name" {
  description = "Name of the IAM instance profile for the Locker EC2 instance."
  type        = string
}

variable "locker_kms_key_arn" {
  description = "ARN of the KMS key dedicated to the Locker for S3 and Lambda data encryption."
  type        = string
}

variable "locker_env_s3_bucket_name" {
  description = "Name of the S3 bucket for storing the Locker's encrypted environment file."
  type        = string
}

variable "locker_secrets_manager_kms_data_arn" {
  description = "ARN of the Secrets Manager secret that stores data for the Locker KMS encryption Lambda."
  type        = string
}

variable "locker_db_secrets_manager_arn" {
  description = "ARN of the Secrets Manager secret for the Locker database credentials."
  type        = string
}

variable "lambda_role_arn_for_kms_encryption" {
  description = "ARN of the IAM role for the Lambda function that encrypts Locker secrets."
  type        = string
}

variable "enable_jump_host" {
  description = "Whether to create a jump host for accessing the Locker."
  type        = bool
  default     = true
}

variable "jump_host_instance_type" {
  description = "Instance type for the Locker jump host."
  type        = string
  default     = "t3.medium"
}
