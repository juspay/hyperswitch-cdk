resource "aws_secretsmanager_secret" "rds_master_secret" {
  count       = var.create_rds_master_secret ? 1 : 0
  name        = "${var.stack_prefix}-${var.rds_master_secret_name}"
  description = "RDS master user secret for ${var.stack_prefix}"
  tags        = var.tags
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "rds_master_secret_version" {
  count = var.create_rds_master_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.rds_master_secret[0].id
  secret_string = jsonencode({
    dbClusterIdentifier = "${var.stack_prefix}-db", # This might need to match actual RDS cluster ID if used by RDS
    dbname              = var.rds_db_name_for_secret,
    engine              = "postgres", # Assuming postgres
    host                = "placeholder.rds.amazonaws.com", # RDS will update this
    password            = var.rds_db_password_for_secret,
    port                = 5432, # Assuming default postgres port
    username            = var.rds_db_user_for_secret
  })
}

resource "aws_secretsmanager_secret" "locker_db_master_secret" {
  count       = var.create_locker_db_master_secret ? 1 : 0
  name        = "${var.stack_prefix}-${var.locker_db_master_secret_name}"
  description = "Locker DB master user secret for ${var.stack_prefix}"
  tags        = var.tags
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "locker_db_master_secret_version" {
  count = var.create_locker_db_master_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.locker_db_master_secret[0].id
  secret_string = jsonencode({
    dbClusterIdentifier = "${var.stack_prefix}-locker-db", # Placeholder
    dbname              = var.locker_db_name_for_secret,
    engine              = "postgres",
    host                = "placeholder.rds.amazonaws.com",
    password            = var.locker_db_password_for_secret,
    port                = 5432,
    username            = var.locker_db_user_for_secret
  })
}

resource "aws_secretsmanager_secret" "locker_kms_data_secret" {
  count       = var.create_locker_kms_data_secret ? 1 : 0
  name        = "${var.stack_prefix}-${var.locker_kms_data_secret_name}"
  description = "Locker KMS data for Lambda encryption for ${var.stack_prefix}"
  tags        = var.tags
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "locker_kms_data_secret_version" {
  count = var.create_locker_kms_data_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.locker_kms_data_secret[0].id
  secret_string = jsonencode(var.locker_kms_data_secret_content)
}

resource "aws_secretsmanager_secret" "hyperswitch_kms_data_secret" {
  count       = var.create_hyperswitch_kms_data_secret ? 1 : 0
  name        = "${var.stack_prefix}-${var.hyperswitch_kms_data_secret_name}"
  description = "Hyperswitch EKS KMS data for Lambda encryption for ${var.stack_prefix}"
  tags        = var.tags
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "hyperswitch_kms_data_secret_version" {
  count = var.create_hyperswitch_kms_data_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.hyperswitch_kms_data_secret[0].id
  secret_string = jsonencode(var.hyperswitch_kms_data_secret_content)
}

# --- Keymanager Secrets ---
resource "aws_secretsmanager_secret" "keymanager_db_master_secret" {
  count       = var.create_keymanager_db_master_secret ? 1 : 0
  name        = "${var.stack_prefix}-${var.keymanager_db_master_secret_name}"
  description = "Keymanager DB master user secret for ${var.stack_prefix}"
  tags        = var.tags
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "keymanager_db_master_secret_version" {
  count = var.create_keymanager_db_master_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.keymanager_db_master_secret[0].id
  secret_string = jsonencode({
    # dbClusterIdentifier = "${var.stack_prefix}-keymanager-db", # Placeholder
    dbname              = var.keymanager_db_name_for_secret,
    engine              = "postgres",
    # host                = "placeholder.rds.amazonaws.com", # RDS will update this if managed
    password            = var.keymanager_db_password_for_secret,
    port                = 5432, # Assuming default postgres port
    username            = var.keymanager_db_user_for_secret
  })
}

resource "aws_secretsmanager_secret" "keymanager_kms_data_secret" {
  count       = var.create_keymanager_kms_data_secret ? 1 : 0
  name        = "${var.stack_prefix}-${var.keymanager_kms_data_secret_name}"
  description = "Keymanager KMS data for Lambda encryption for ${var.stack_prefix}"
  tags        = var.tags
  recovery_window_in_days = var.recovery_window_in_days
}

resource "aws_secretsmanager_secret_version" "keymanager_kms_data_secret_version" {
  count = var.create_keymanager_kms_data_secret ? 1 : 0
  secret_id     = aws_secretsmanager_secret.keymanager_kms_data_secret[0].id
  secret_string = jsonencode(var.keymanager_kms_data_secret_content)
}
