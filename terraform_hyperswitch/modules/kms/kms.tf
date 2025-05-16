locals {
  default_policy = jsonencode({
    Version = "2012-10-17",
    Id      = "key-default-1",
    Statement = [
      {
        Sid   = "Enable IAM User Permissions",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.aws_account_id}:root"
        },
        Action   = "kms:*",
        Resource = "*"
      }
      # Add other default statements if necessary, e.g., for specific service roles
    ]
  })
}

resource "aws_kms_key" "this" {
  description             = var.description
  key_usage               = var.key_usage
  customer_master_key_spec = var.key_spec # Renamed from key_spec to customer_master_key_spec
  enable_key_rotation     = var.enable_key_rotation
  pending_window_in_days  = var.pending_window_in_days # This is for scheduling deletion, CDK uses it for removal policy
  deletion_window_in_days = var.deletion_window_in_days # Actual deletion window
  policy                  = var.policy == null ? local.default_policy : var.policy
  tags                    = var.tags
}

resource "aws_kms_alias" "this" {
  name          = var.key_alias_name
  target_key_id = aws_kms_key.this.key_id
}
