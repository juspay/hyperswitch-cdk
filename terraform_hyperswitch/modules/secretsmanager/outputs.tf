output "rds_master_secret_arn" {
  description = "ARN of the RDS master user secret."
  value       = var.create_rds_master_secret ? aws_secretsmanager_secret.rds_master_secret[0].arn : null
  depends_on  = [aws_secretsmanager_secret.rds_master_secret]
}

output "locker_db_master_secret_arn" {
  description = "ARN of the Locker DB master user secret."
  value       = var.create_locker_db_master_secret ? aws_secretsmanager_secret.locker_db_master_secret[0].arn : null
  depends_on  = [aws_secretsmanager_secret.locker_db_master_secret]
}

output "locker_kms_data_secret_arn" {
  description = "ARN of the Locker KMS data secret."
  value       = var.create_locker_kms_data_secret ? aws_secretsmanager_secret.locker_kms_data_secret[0].arn : null
  depends_on  = [aws_secretsmanager_secret.locker_kms_data_secret]
}

output "hyperswitch_kms_data_secret_arn" {
  description = "ARN of the Hyperswitch EKS KMS data secret."
  value       = var.create_hyperswitch_kms_data_secret ? aws_secretsmanager_secret.hyperswitch_kms_data_secret[0].arn : null
  depends_on  = [aws_secretsmanager_secret.hyperswitch_kms_data_secret]
}

output "keymanager_db_master_secret_arn" {
  description = "ARN of the Keymanager DB master user secret."
  value       = var.create_keymanager_db_master_secret ? aws_secretsmanager_secret.keymanager_db_master_secret[0].arn : null
  depends_on  = [aws_secretsmanager_secret.keymanager_db_master_secret]
}

output "keymanager_kms_data_secret_arn" {
  description = "ARN of the Keymanager KMS data secret."
  value       = var.create_keymanager_kms_data_secret ? aws_secretsmanager_secret.keymanager_kms_data_secret[0].arn : null
  depends_on  = [aws_secretsmanager_secret.keymanager_kms_data_secret]
}
