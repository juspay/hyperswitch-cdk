variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., production, staging)"
  type        = string

}

variable "management_subnet_id" {
  description = "ID of the management subnet for external jump host"
  type        = string
}

variable "utils_subnet_id" {
  description = "ID of the utils subnet for internal jump host"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Optional variables for database connections
variable "rds_security_group_id" {
  description = "Security group ID of the RDS instance"
  type        = string
  default     = null
}

variable "elasticache_security_group_id" {
  description = "Security group ID of the ElastiCache cluster"
  type        = string
  default     = null
}

variable "locker_ec2_security_group_id" {
  description = "Security group ID of the locker EC2 instance"
  type        = string
  default     = null
}

variable "locker_db_security_group_id" {
  description = "Security group ID of the locker database"
  type        = string
  default     = null
}

# Required infrastructure references
variable "kms_key_arn" {
  description = "ARN of the KMS key for SSM encryption"
  type        = string
}

variable "vpce_security_group_id" {
  description = "Security group ID for VPC endpoints"
  type        = string
}
