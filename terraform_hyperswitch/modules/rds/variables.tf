variable "stack_prefix" {
  description = "Prefix for stack resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the RDS instance/cluster will be deployed."
  type        = string
}

variable "db_subnet_group_name" {
  description = "Name of the DB subnet group. If null, one will be created."
  type        = string
  default     = null
}

variable "database_zone_subnet_ids" {
  description = "List of subnet IDs for the 'database-zone' (for RDS)."
  type        = list(string)
}

variable "is_standalone_deployment" {
  description = "Flag to determine if deploying a standalone DB instance or an Aurora cluster."
  type        = bool
}

variable "db_name" {
  description = "The name of the database to create."
  type        = string
}

variable "db_port" {
  description = "The port on which the DB accepts connections."
  type        = number
}

variable "db_username" {
  description = "Username for the master DB user. Password will be from Secrets Manager."
  type        = string
}

variable "master_user_secret_arn" {
  description = "ARN of the Secrets Manager secret holding the master username and password."
  type        = string
}

# Standalone DB Instance Configuration
variable "standalone_instance_type" {
  description = "Instance type for the standalone RDS instance (e.g., 'db.t3.micro')."
  type        = string
  default     = "db.t3.micro"
}

variable "standalone_postgres_engine_version" {
  description = "PostgreSQL engine version for standalone instance."
  type        = string
  default     = "14" # Matches CDK VER_14
}

# Aurora Cluster Configuration
variable "aurora_writer_instance_type" {
  description = "Instance type for the Aurora writer instance (e.g., 'db.t3.medium')."
  type        = string
  default     = "db.t3.medium"
}

variable "aurora_reader_instance_type" {
  description = "Instance type for the Aurora reader instance (e.g., 'db.t3.medium')."
  type        = string
  default     = "db.t3.medium"
}

variable "aurora_reader_count" {
  description = "Number of reader instances for Aurora cluster (0 for standalone-like Aurora)."
  type        = number
  default     = 1 # CDK default is 1 reader unless isStandalone is true for the main stack
}

variable "aurora_postgres_engine_version" {
  description = "Aurora PostgreSQL engine version."
  type        = string
  default     = "14.11" # Matches CDK VER_14_11
}

variable "storage_encrypted" {
  description = "Specifies whether the DB instance is encrypted."
  type        = bool
  default     = true # CDK default for Aurora
}

variable "skip_final_snapshot" {
  description = "Determines whether a final DB snapshot is created before the DB instance is deleted."
  type        = bool
  default     = true # CDK RemovalPolicy.DESTROY implies skip_final_snapshot = true
}

variable "security_group_name" {
  description = "Name for the RDS security group."
  type        = string
  default     = "Hyperswitch-db-SG" # From CDK
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

# For Standalone RDS Schema Initialization
variable "create_schema_init_lambda_trigger" {
  description = "Whether to create resources for standalone RDS schema initialization (S3 bucket, Lambda, Trigger)."
  type        = bool
  default     = false # This will be true if is_standalone_deployment is true for the main Hyperswitch stack
}

variable "rds_schema_s3_bucket_name" {
  description = "Name of the S3 bucket containing schema.sql and migration_runner.zip."
  type        = string
  default     = "" # Will be passed from the main s3 module output
}

variable "lambda_role_arn_for_schema_init" {
  description = "ARN of the IAM role for the schema initialization Lambda."
  type        = string
  default     = ""
}

variable "isolated_subnet_ids_for_lambda" {
  description = "List of isolated subnet IDs for the schema initialization Lambda."
  type        = list(string)
  default     = []
}
