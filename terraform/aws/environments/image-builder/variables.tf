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

variable "ami_id" {
  description = "Base AMI ID for image building"
  type        = string
  default     = null
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}

