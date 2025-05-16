variable "instance_name_prefix" {
  description = "Prefix for the EC2 instance name and related resources (e.g., SG, KeyPair)."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the EC2 instance will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs where the EC2 instance can be launched. Typically one for non-ASG."
  type        = list(string)
}

variable "instance_type" {
  description = "EC2 instance type (e.g., 't2.micro', 't3.medium')."
  type        = string
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance. If null, latest Amazon Linux 2 is used."
  type        = string
  default     = null
}

variable "key_pair_name" {
  description = "Name of an existing EC2 KeyPair. If null, a new one will be created."
  type        = string
  default     = null
}

variable "create_new_key_pair" {
  description = "Whether to create a new key pair for this instance if key_pair_name is null."
  type        = bool
  default     = true # Matches CDK behavior of creating CfnKeyPair
}

variable "security_group_ids" {
  description = "List of security group IDs to associate with the instance. If empty, a new SG will be created."
  type        = list(string)
  default     = []
}

variable "create_new_security_group" {
  description = "Whether to create a new security group for this instance if security_group_ids is empty."
  type        = bool
  default     = true # Matches CDK behavior
}

variable "security_group_name_prefix" {
  description = "Prefix for the new security group name if created."
  type        = string
  default     = "ec2-sg"
}

variable "security_group_allow_all_outbound" {
  description = "Whether the new security group should allow all outbound traffic."
  type        = bool
  default     = true
}

variable "security_group_ingress_rules" {
  description = "List of ingress rules for the new security group. Each rule is an object."
  type = list(object({
    description      = optional(string)
    from_port        = number
    to_port          = number
    protocol         = string
    cidr_blocks      = optional(list(string))
    source_security_group_id = optional(string)
  }))
  default = []
}

variable "user_data_base64" {
  description = "User data for the instance, base64 encoded. Use `filebase64()` for files."
  type        = string
  default     = null
}

variable "associate_public_ip_address" {
  description = "Whether to associate a public IP address with the instance."
  type        = bool
  default     = false # CDK default is false unless specified in vpcSubnets or by property
}

variable "ssm_session_permissions" {
  description = "Whether to grant SSM session permissions to the instance role."
  type        = bool
  default     = false # CDK default
}

variable "iam_instance_profile_name" {
  description = "Name of an existing IAM instance profile to associate with the instance. If null, no profile is attached by this module directly (can be done via higher level constructs)."
  type        = string
  default     = null
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}
