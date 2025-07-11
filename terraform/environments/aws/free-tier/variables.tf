variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
}

variable "stack_name" {
  description = "Name of the stack - used as prefix for all resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "hyperswitchuser"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "hyperswitch_db"
}

variable "admin_api_key" {
  description = "Admin API key for Hyperswitch"
  type        = string
  sensitive   = true
}

variable "router_version" {
  description = "Hyperswitch Router version to deploy"
  type        = string
  default     = "v1.115.0"
}

variable "control_center_version" {
  description = "Hyperswitch Control Center version to deploy"
  type        = string
  default     = "v1.37.2"
}

variable "sdk_version" {
  description = "Hyperswitch SDK version to deploy"
  type        = string
  default     = "0.27.2"
}

variable "sdk_sub_version" {
  description = "Hyperswitch SDK sub-version to deploy"
  type        = string
  default     = "v1"
}
