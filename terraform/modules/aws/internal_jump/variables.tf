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

variable "common_tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "ami_id" {
  description = "AMI ID for the jump host (optional - defaults to latest Amazon Linux)"
  type        = string
  default     = null
}

variable "external_jump_sg_id" {
  description = "Security group ID of the external jump host for SSH access"
  type        = string
}

variable "rds_sg_id" {
  description = "Security group ID of the RDS instance"
  type        = string
  default     = null
}

variable "elasticache_sg_id" {
  description = "Security group ID of the ElastiCache cluster"
  type        = string
  default     = null
}

variable "locker_ec2_sg_id" {
  description = "Security group ID of the locker EC2 instance"
  type        = string
  default     = null
}

variable "locker_db_sg_id" {
  description = "Security group ID of the locker database"
  type        = string
  default     = null
}
