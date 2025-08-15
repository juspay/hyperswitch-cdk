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

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpn_ips" {
  description = "List of VPN IPs for security group rules"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

