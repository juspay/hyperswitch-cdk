variable "stack_prefix" {
  description = "Prefix for stack resources."
  type        = string
  default     = "hyperswitch"
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "base_ami_id" {
  description = "Base AMI ID for the image recipes. If null, latest Amazon Linux 2 is used."
  type        = string
  default     = null # Will use data source for Amazon Linux 2 if null
}

variable "iam_instance_profile_name" {
  description = "Name of the IAM instance profile for Image Builder instances (e.g., 'StationInstanceProfile')."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where Image Builder infrastructure will be created."
  type        = string
}

variable "subnet_id_for_image_builder" {
  description = "ID of the subnet to use for Image Builder infrastructure configuration."
  type        = string
}

variable "security_group_id_for_image_builder" {
  description = "ID of the security group to use for Image Builder infrastructure configuration."
  type        = string
}

variable "lambda_role_arn_for_triggers" {
  description = "ARN of the IAM role for Lambda functions that trigger pipelines and record AMIs."
  type        = string
}

# Component file paths (relative to the module or a shared location)
variable "squid_component_file_path" {
  description = "Path to the Squid component YAML file."
  type        = string
  default     = "components/squid.yml" # Assuming it's in a 'components' subdir of this module or root
}

variable "envoy_component_file_path" {
  description = "Path to the Envoy component YAML file."
  type        = string
  default     = "components/envoy.yml"
}

variable "base_component_file_path" {
  description = "Path to the Base component YAML file."
  type        = string
  default     = "components/base.yml"
}

# SSM Parameter names for storing AMI IDs
variable "squid_ami_ssm_parameter_name" {
  description = "Name of the SSM parameter to store the Squid AMI ID."
  type        = string
  default     = "/hyperswitch/ami/squid" # Example, align with CDK if possible
}

variable "envoy_ami_ssm_parameter_name" {
  description = "Name of the SSM parameter to store the Envoy AMI ID."
  type        = string
  default     = "/hyperswitch/ami/envoy"
}

variable "base_ami_ssm_parameter_name" {
  description = "Name of the SSM parameter to store the Base AMI ID."
  type        = string
  default     = "/hyperswitch/ami/base"
}
