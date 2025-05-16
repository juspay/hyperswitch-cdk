variable "stack_prefix" {
  description = "Prefix for stack resources (e.g., 'hyperswitch')."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

variable "create_rds_master_secret" {
  description = "Whether to create the Secrets Manager secret for RDS master user."
  type        = bool
  default     = false
}

variable "rds_master_secret_name" {
  description = "Name for the RDS master user secret."
  type        = string
  default     = "hypers-db-master-user-secret" # From CDK
}

variable "rds_db_name_for_secret" {
  description = "Database name to store in the RDS secret."
  type        = string
}

variable "rds_db_user_for_secret" {
  description = "Database username to store in the RDS secret."
  type        = string
}

variable "rds_db_password_for_secret" {
  description = "Database password to store in the RDS secret."
  type        = string
  sensitive   = true
}

variable "create_locker_db_master_secret" {
  description = "Whether to create the Secrets Manager secret for Locker DB master user."
  type        = bool
  default     = false
}

variable "locker_db_master_secret_name" {
  description = "Name for the Locker DB master user secret."
  type        = string
  default     = "LockerDbMasterUserSecret" # From CDK
}

variable "locker_db_name_for_secret" {
  description = "Database name to store in the Locker DB secret."
  type        = string
  default     = "locker"
}

variable "locker_db_user_for_secret" {
  description = "Database username to store in the Locker DB secret."
  type        = string
}

variable "locker_db_password_for_secret" {
  description = "Database password to store in the Locker DB secret."
  type        = string
  sensitive   = true
}

variable "create_locker_kms_data_secret" {
  description = "Whether to create the Secrets Manager secret for Locker KMS data (used by Lambda)."
  type        = bool
  default     = false
}

variable "locker_kms_data_secret_name" {
  description = "Name for the Locker KMS data secret."
  type        = string
  default     = "LockerKmsDataSecret" # From CDK
}

variable "locker_kms_data_secret_content" {
  description = "A map representing the JSON object for the LockerKmsDataSecret. Keys like db_username, db_password, db_host, master_key, private_key, public_key, kms_id, region."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "create_hyperswitch_kms_data_secret" {
  description = "Whether to create the Secrets Manager secret for Hyperswitch EKS KMS data (used by Lambda)."
  type        = bool
  default     = false
}

variable "hyperswitch_kms_data_secret_name" {
  description = "Name for the Hyperswitch EKS KMS data secret."
  type        = string
  default     = "HyperswitchKmsDataSecret" # From CDK
}

variable "hyperswitch_kms_data_secret_content" {
  description = "A map representing the JSON object for the HyperswitchKmsDataSecret. Keys like db_password, jwt_secret, master_key, admin_api_key, kms_id, region, locker_public_key, tenant_private_key."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "create_keymanager_db_master_secret" {
  description = "Whether to create the Secrets Manager secret for Keymanager DB master user."
  type        = bool
  default     = false
}

variable "keymanager_db_master_secret_name" {
  description = "Name for the Keymanager DB master user secret."
  type        = string
  default     = "KeymanagerDbMasterUserSecret" # Example
}

variable "keymanager_db_name_for_secret" {
  description = "Database name to store in the Keymanager DB secret."
  type        = string
}

variable "keymanager_db_user_for_secret" {
  description = "Database username to store in the Keymanager DB secret."
  type        = string
}

variable "keymanager_db_password_for_secret" {
  description = "Database password to store in the Keymanager DB secret."
  type        = string
  sensitive   = true
}

variable "create_keymanager_kms_data_secret" {
  description = "Whether to create the Secrets Manager secret for Keymanager KMS data (used by Lambda)."
  type        = bool
  default     = false
}

variable "keymanager_kms_data_secret_name" {
  description = "Name for the Keymanager KMS data secret."
  type        = string
  default     = "KeymanagerKmsDataSecret" # Example
}

variable "keymanager_kms_data_secret_content" {
  description = "A map representing the JSON object for the KeymanagerKmsDataSecret."
  type        = map(string)
  sensitive   = true
  default     = {}
}

variable "recovery_window_in_days" {
  description = "Number of days that AWS Secrets Manager waits before it can delete the secret."
  type        = number
  default     = 7 # CDK default for RemovalPolicy.DESTROY is often 7 days for secrets
}
