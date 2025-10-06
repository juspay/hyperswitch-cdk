# Variables
variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "s3_bucket" {
  description = "S3 bucket containing the allowedlist.txt"
  type        = string
}

variable "s3_key" {
  description = "S3 key for the allowedlist.txt file"
  type        = string
}

variable "new_domains" {
  description = "List of new domains to process and add to whitelist"
  type        = list(string)
  default     = []
}
