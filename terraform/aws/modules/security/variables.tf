variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "common_tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

variable "is_production" {
  description = "Boolean indicating if the environment is production"
  type        = bool
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC"
  type        = string
}

variable "vpn_ips" {
  description = "List of VPN IPs for security group rules"
  type        = list(string)
  default     = []
}

variable "db_user" {
  description = "Username for the database"
  type        = string
}

variable "db_name" {
  description = "Name of the database"
  type        = string
}

variable "db_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "Secret for JWT authentication"
  type        = string
  sensitive   = true
}

variable "master_key" {
  description = "Master key for encryption"
  type        = string
  sensitive   = true
}

variable "admin_api_key" {
  description = "API key for admin access"
  type        = string
  sensitive   = true
}

variable "locker_public_key" {
  description = "Public key for the locker service"
  type        = string
  sensitive   = true
}

variable "tenant_private_key" {
  description = "Private key for the tenant"
  type        = string
  sensitive   = true
}
