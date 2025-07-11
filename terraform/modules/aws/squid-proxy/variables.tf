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
  description = "List of subnet IDs for the proxy instances"
  type        = map(list(string))
}

variable "squid_image_ami" {
  description = "AMI ID for the Squid image"
  type        = string
}

variable "eks_cluster_security_group_id" {
  description = "ID of the EKS cluster security group"
  type        = string
}

variable "proxy_config_bucket_name" {
  description = "Name of the S3 bucket for proxy configurations"
  type        = string
}

variable "proxy_config_bucket_arn" {
  description = "ARN of the S3 bucket for proxy configurations"
  type        = string
}
