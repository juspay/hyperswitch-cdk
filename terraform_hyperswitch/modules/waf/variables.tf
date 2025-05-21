variable "stack_prefix" {
  description = "Prefix for all resources created by this stack"
  type        = string
}

variable "rate_limit" {
  description = "The maximum number of requests allowed from an IP in 5 minutes"
  type        = number
  default     = 2000
}

variable "tags" {
  description = "A map of tags to add to all resources"
  type        = map(string)
  default     = {}
}