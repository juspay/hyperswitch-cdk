variable "stack_name" {
  description = "Name of the stack"
  type        = string
}

variable "common_tags" {
  description = "Common tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster will be deployed"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "vpn_ips" {
  description = "List of VPN IPs to allow access to the EKS cluster"
  type        = list(string)
  default     = []
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the EKS cluster"
  type        = map(list(string))
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "control_plane_subnet_ids" {
  description = "List of control plane subnet IDs for the EKS cluster"
  type        = list(string)
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for EKS encryption"
  type        = string
}

variable "log_retention_days" {
  description = "Retention period for EKS CloudWatch logs in days"
  type        = number
}

variable "rds_security_group_id" {
  description = "ID of the RDS Security Group"
  type        = string
}

variable "elasticache_security_group_id" {
  description = "ID of the ElastiCache Security Group"
  type        = string

}
