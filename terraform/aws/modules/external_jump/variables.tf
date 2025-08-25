variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "subnet_id" {
  description = "ID of the subnet to deploy the jump host"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "Name of the EC2 Key Pair"
  type        = string
  default     = null
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for SSM encryption"
  type        = string
}

variable "common_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "AMI ID for the jump host (optional - defaults to latest Amazon Linux 2)"
  type        = string
  default     = null
}

variable "enable_ssm_session_manager" {
  description = "Enable SSM Session Manager access"
  type        = bool
  default     = true
}

variable "enable_ssm_full_access" {
  description = "Enable full SSM access (AmazonSSMFullAccess policy)"
  type        = bool
  default     = false
}

variable "vpce_security_group_id" {
  description = "Security group ID for VPC endpoints"
  type        = string
  default     = null
}
