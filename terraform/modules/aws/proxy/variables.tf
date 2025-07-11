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

variable "envoy_image_ami" {
  description = "AMI ID for the Envoy image"
  type        = string
}

variable "squid_image_ami" {
  description = "AMI ID for the Squid image"
  type        = string
}

variable "internal_alb_security_group_id" {
  description = "ID of the Internal Load Balancer Security Group"
  type        = string
}

variable "external_alb_security_group_id" {
  description = "ID of the External ALB Security Group"
  type        = string
}

variable "eks_cluster_security_group_id" {
  description = "ID of the EKS cluster security group"
  type        = string
}

variable "internal_alb_domain_name" {
  description = "ID of the Istio Internal ALB Security Group"
  type        = string
}

variable "external_alb_distribution_domain_name" {
  description = "Domain name of the external ALB"
  type        = string
}

variable "envoy_target_group_arn" {
  description = "ARN of the Envoy target group"
  type        = string
}

variable "squid_target_group_arn" {
  description = "ARN of the Squid target group"
  type        = string
}

variable "squid_internal_lb_sg_id" {
  description = "ID of the Squid Internal Load Balancer Security Group"
  type        = string
}
