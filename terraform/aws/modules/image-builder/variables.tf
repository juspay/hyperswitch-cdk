# Variables
variable "ami_id" {
  description = "Base AMI ID for image building"
  type        = string
  default     = null
}

variable "stack_name" {
  description = "Name of the stack"
  type        = string
  default     = "imagebuilder-stack"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "az_count" {
  description = "Number of availability zones to use"
  type        = number
  default     = 2
}
