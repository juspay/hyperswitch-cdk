variable "name" {
  description = "Name for the VPC."
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "max_azs" {
  description = "Maximum number of Availability Zones to use for the VPC."
  type        = number
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
}

variable "stack_prefix" {
  description = "Prefix for stack resources."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

// Variables to control creation of specific named subnets based on CDK's networking.ts
variable "enable_eks_worker_nodes_one_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_utils_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_management_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_locker_database_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_service_layer_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_data_stack_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_external_incoming_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_database_zone_subnets" { # For main RDS, distinct from locker_database_zone
  type    = bool
  default = false
}
variable "enable_outgoing_proxy_lb_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_outgoing_proxy_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_locker_server_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_elasticache_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_incoming_npci_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_eks_control_plane_zone_subnets" {
  type    = bool
  default = false
}
variable "enable_incoming_web_envoy_zone_subnets" {
  type    = bool
  default = false
}

# Default Subnet Names from CDK (lib/aws/networking.ts SubnetNames enum and Vpc class)
# These are used if the more specific enable_..._subnets are false,
# allowing for a basic public/private/isolated setup.
variable "default_public_subnet_name_prefix" {
  description = "Prefix for default public subnets."
  type        = string
  default     = "public-subnet"
}

variable "default_private_subnet_name_prefix" {
  description = "Prefix for default private subnets (with NAT)."
  type        = string
  default     = "private-subnet"
}

variable "default_isolated_subnet_name_prefix" {
  description = "Prefix for default isolated subnets."
  type        = string
  default     = "isolated-subnet"
}

# Default CIDR masks for the three main types of subnets if not using the detailed CDK structure
variable "public_subnet_cidr_mask" {
  description = "Default CIDR mask for public subnets if not using detailed CDK structure."
  type        = number
  default     = 24
}

variable "private_subnet_cidr_mask" {
  description = "Default CIDR mask for private subnets if not using detailed CDK structure."
  type        = number
  default     = 24
}

variable "isolated_subnet_cidr_mask" {
  description = "Default CIDR mask for isolated subnets if not using detailed CDK structure."
  type        = number
  default     = 24
}

variable "enable_nat_gateway" {
  description = "Enable NAT gateway for private subnets."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway instead of one per AZ."
  type        = bool
  default     = false
}
