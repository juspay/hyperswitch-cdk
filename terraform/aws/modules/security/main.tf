# Aws Current Region
data "aws_region" "current" {}

# Aws Caller Identity
data "aws_caller_identity" "current" {}

# ==========================================================
#                  KMS Keys and Aliases
# ==========================================================

# KMS Key for Hyperswitch
resource "aws_kms_key" "hyperswitch_kms_key" {
  description             = "KMS key for encrypting the objects in an S3 bucket"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = false # CDK: enableKeyRotation: false

  tags = var.common_tags
}

# Hyperswitch KMS Key Alias
resource "aws_kms_alias" "hyperswitch_kms_key_alias" {
  name          = "alias/${var.stack_name}-kms-key"
  target_key_id = aws_kms_key.hyperswitch_kms_key.key_id
}

# KMS Key for SSM
resource "aws_kms_key" "hyperswitch_ssm_kms_key" {
  description             = "KMS key for encrypting the objects in an S3 bucket"
  key_usage               = "ENCRYPT_DECRYPT"
  deletion_window_in_days = 7
  enable_key_rotation     = true # CDK: enableKeyRotation: true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-ssm-kms-key"
  })
}

# Hyperswitch SSM KMS Key Alias
resource "aws_kms_alias" "hyperswitch_ssm_kms_key_alias" {
  name          = "alias/${var.stack_name}-ssm-kms-key"
  target_key_id = aws_kms_key.hyperswitch_ssm_kms_key.key_id
}

# ==========================================================
#                      Secrets Manager
# ==========================================================

resource "aws_secretsmanager_secret" "hyperswitch" {
  name        = "${var.stack_name}-kms-secrets"
  description = "KMS encryptable secrets for Hyperswitch"

  # only for development purposes
  recovery_window_in_days        = 0
  force_overwrite_replica_secret = true

  kms_key_id = aws_kms_key.hyperswitch_kms_key.key_id
}

resource "aws_secretsmanager_secret_version" "hyperswitch" {
  secret_id = aws_secretsmanager_secret.hyperswitch.id

  secret_string = jsonencode({
    db_password        = var.db_password
    jwt_secret         = var.jwt_secret
    master_key         = var.master_key
    admin_api_key      = var.admin_api_key
    kms_id             = aws_kms_key.hyperswitch_kms_key.key_id
    region             = data.aws_region.current.name
    locker_public_key  = var.locker_public_key
    tenant_private_key = var.tenant_private_key
  })
}

# RDS Database Secret
resource "aws_secretsmanager_secret" "db_master" {
  name        = "${var.stack_name}-db-master-user-secret"
  description = "Database master user credentials"

  # only for development purposes
  recovery_window_in_days        = 0
  force_overwrite_replica_secret = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-db-master-user-secret"

  })
}

resource "aws_secretsmanager_secret_version" "db_master" {
  secret_id = aws_secretsmanager_secret.db_master.id
  secret_string = jsonencode({
    dbname   = var.db_name
    username = var.db_user
    password = var.db_password
  })
}
