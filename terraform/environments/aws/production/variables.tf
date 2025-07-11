variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-1"
}

variable "stack_name" {
  description = "Name of the stack (used for resource naming)"
  type        = string
  default     = "hyperswitch"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "Production"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpn_ips" {
  description = "List of VPN IPs for security group rules"
  type        = list(string)
  default     = ["3.7.40.245/32", "13.232.74.226/32", "65.1.52.128/32"]
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

variable "kubernetes_version" {
  description = "Kubernetes version for EKS cluster"
  type        = string
  default     = "1.28"
}

variable "helm_version" {
  description = "Helm version to use"
  type        = string
  default     = "3.12"
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 30
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

variable "db_port" {
  description = "Port for the database"
  type        = number
  default     = 5432
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

variable "locker_enabled" {
  description = "Flag to enable or disable the locker feature"
  type        = bool
  default     = false
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

variable "envoy_image_ami" {
  description = "AMI ID for the Envoy image"
  type        = string
}

variable "squid_image_ami" {
  description = "AMI ID for the Squid image"
  type        = string
}
