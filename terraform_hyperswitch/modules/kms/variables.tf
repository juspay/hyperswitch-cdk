variable "key_alias_name" {
  description = "Alias for the KMS key (e.g., 'alias/my-app-key')."
  type        = string
}

variable "description" {
  description = "Description for the KMS key."
  type        = string
  default     = "KMS key"
}

variable "key_usage" {
  description = "Specifies the intended use of the key. Defaults to ENCRYPT_DECRYPT."
  type        = string
  default     = "ENCRYPT_DECRYPT" # Or SYMMETRIC_DEFAULT for some CDK versions/uses
}

variable "key_spec" {
  description = "Specifies the type of key material in the KMS key. Defaults to SYMMETRIC_DEFAULT."
  type        = string
  default     = "SYMMETRIC_DEFAULT"
}

variable "enable_key_rotation" {
  description = "Specifies whether key rotation is enabled. Defaults to true."
  type        = bool
  default     = true
}

variable "pending_window_in_days" {
  description = "Duration in days after which the key is deleted after destruction of the resource."
  type        = number
  default     = 7
}

variable "deletion_window_in_days" {
  description = "Waiting period for scheduled key deletion. Defaults to 7 days."
  type        = number
  default     = 7 # CDK default is 7 for pendingWindow, this is for deletion_window_in_days
}

variable "tags" {
  description = "A map of tags to assign to the KMS key."
  type        = map(string)
  default     = {}
}

variable "policy" {
  description = "A valid KMS key policy JSON as a string. If not provided, a default policy is created."
  type        = string
  default     = null
}

variable "aws_account_id" {
  description = "AWS Account ID for constructing default policy if needed."
  type        = string
}
