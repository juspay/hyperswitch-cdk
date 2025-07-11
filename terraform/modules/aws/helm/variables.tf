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

variable "subnet_ids" {
  description = "List of subnet IDs for the RDS instance"
  type        = map(list(string))
}

variable "vpn_ips" {
  description = "List of VPN IPs for the security group"
  type        = list(string)
  default     = []
}

variable "private_ecr_repository" {
  description = "ECR repository for private images"
  type        = string
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "eks_cluster_endpoint" {
  description = "Endpoint of the EKS cluster"
  type        = string
}

variable "eks_cluster_ca_certificate" {
  description = "CA certificate of the EKS cluster"
  type        = string
}

variable "eks_cluster_security_group_id" {
  description = "Security group ID for the EKS cluster"
  type        = string
}

variable "alb_controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller"
  type        = string
}

variable "hyperswitch_kms_key_id" {
  description = "ID of the KMS key used for Hyperswitch"
  type        = string
}

variable "hyperswitch_service_account_role_arn" {
  description = "ARN of the Hyperswitch service account role"
  type        = string
}

variable "istio_service_account_role_arn" {
  description = "ARN of the Istio service account role"
  type        = string
}

variable "grafana_service_account_role_arn" {
  description = "ARN of the Grafana service account role"
  type        = string
}

variable "kms_secrets" {
  description = "Map of KMS secrets used in Hyperswitch"
  type        = map(string)
}

variable "locker_enabled" {
  description = "Flag to enable or disable the locker feature"
  type        = bool
  default     = false
}

variable "locker_public_key" {
  description = "Public key for the locker feature"
  type        = string
}

variable "tenant_private_key" {
  description = "Private key for the locker feature"
  type        = string
}

variable "db_password" {
  description = "Password for the RDS database"
  type        = string
}

variable "rds_cluster_endpoint" {
  description = "RDS cluster writer endpoint"
  type        = string
}

variable "rds_cluster_reader_endpoint" {
  description = "RDS cluster reader endpoint"
  type        = string
}

variable "elasticache_cluster_endpoint_address" {
  description = "ElastiCache Redis endpoint address"
  type        = string
}

variable "sdk_version" {
  description = "Version of the SDK to be used"
  type        = string
}

variable "sdk_distribution_domain_name" {
  description = "Domain name of the SDK distribution"
  type        = string
}

variable "external_alb_distribution_domain_name" {
  description = "Domain name of the external ALB distribution"
  type        = string
}

variable "squid_nlb_dns_name" {
  description = "DNS name of the Squid NLB"
  type        = string

}
