variable "stack_prefix" {
  description = "Prefix for stack resources."
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC where the ElastiCache cluster will be deployed."
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the ElastiCache subnet group. CDK uses publicSubnets, which is unusual."
  type        = list(string)
}

variable "cluster_name" {
  description = "Name for the ElastiCache cluster."
  type        = string
  default     = "hs-elasticache" # From CDK
}

variable "node_type" {
  description = "Cache node type for the ElastiCache cluster."
  type        = string
  default     = "cache.t3.micro" # From CDK
}

variable "engine" {
  description = "Cache engine to be used for this cluster."
  type        = string
  default     = "redis"
}

variable "num_cache_nodes" {
  description = "Number of cache nodes that the cache cluster should have."
  type        = number
  default     = 1
}

variable "port" {
  description = "The port number on which each of the cache nodes will accept connections."
  type        = number
  default     = 6379
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "security_group_name" {
  description = "Name for the ElastiCache security group."
  type        = string
  default     = "Hyperswitch-elasticache-SG" # From CDK
}
