resource "aws_s3_bucket" "rds_schema_bucket" {
  count  = var.create_rds_schema_bucket ? 1 : 0
  bucket = "${var.stack_prefix}-schema-${var.aws_account_id}-${var.aws_region}${var.rds_schema_bucket_name_suffix == "" ? "" : "-${var.rds_schema_bucket_name_suffix}"}"
  tags   = var.tags
  force_destroy = true 
}

resource "aws_s3_bucket_public_access_block" "rds_schema_bucket_public_access" {
  count                   = var.create_rds_schema_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.rds_schema_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "locker_env_bucket" {
  count  = var.create_locker_env_bucket ? 1 : 0
  bucket = "${var.locker_env_bucket_name_suffix}-${var.aws_account_id}-${var.aws_region}"
  tags   = var.tags
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "locker_env_bucket_public_access" {
  count                   = var.create_locker_env_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.locker_env_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "locker_env_bucket_encryption" {
  count  = var.create_locker_env_bucket && var.locker_kms_key_arn_for_bucket_encryption != null ? 1 : 0
  bucket = aws_s3_bucket.locker_env_bucket[0].bucket
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.locker_kms_key_arn_for_bucket_encryption
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_policy" "locker_env_bucket_ssl" {
  count  = var.create_locker_env_bucket ? 1 : 0
  bucket = aws_s3_bucket.locker_env_bucket[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "AllowSSLRequestsOnly", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.locker_env_bucket[0].arn, "${aws_s3_bucket.locker_env_bucket[0].arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }] })
}

resource "aws_s3_bucket" "sdk_bucket" {
  count  = var.create_sdk_bucket ? 1 : 0
  bucket = "${var.stack_prefix}-${var.sdk_bucket_name_suffix}-${var.aws_account_id}-${var.aws_region}"
  tags   = var.tags
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "sdk_bucket_public_access" {
  count                   = var.create_sdk_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.sdk_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "sdk_bucket_cors" {
  count  = var.create_sdk_bucket ? 1 : 0
  bucket = aws_s3_bucket.sdk_bucket[0].id
  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = []
    max_age_seconds = 3000
  }
}

resource "aws_cloudfront_origin_access_identity" "sdk_oai" { # Added for EKS SDK CloudFront
  count   = var.create_sdk_bucket ? 1 : 0 # Assuming OAI is needed if SDK bucket is created for EKS
  comment = "OAI for ${aws_s3_bucket.sdk_bucket[0].bucket}"
}

resource "aws_s3_bucket_policy" "sdk_bucket_policy_for_cloudfront" {
  count  = var.create_sdk_bucket ? 1 : 0
  bucket = aws_s3_bucket.sdk_bucket[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly",
        Effect    = "Allow",
        Principal = { Service = "cloudfront.amazonaws.com" }, # More secure than OAI directly in some views
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.sdk_bucket[0].arn}/*",
        Condition = { StringEquals = { "AWS:SourceArn" = "arn:aws:cloudfront::${var.aws_account_id}:distribution/*" } } # Replace with actual CF dist ARN if known, or keep broad
      },
      { # Alternative using OAI
        Sid    = "AllowOAIReadOnly",
        Effect = "Allow",
        Principal = { CanonicalUser = aws_cloudfront_origin_access_identity.sdk_oai[0].s3_canonical_user_id },
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.sdk_bucket[0].arn}/*"
      }
    ]
  })
  depends_on = [aws_cloudfront_origin_access_identity.sdk_oai]
}


resource "aws_s3_bucket" "proxy_config_bucket" {
  count  = var.create_proxy_config_bucket ? 1 : 0
  bucket = "${var.proxy_config_bucket_name_suffix}-${var.aws_account_id}-${var.aws_region}"
  tags   = var.tags
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "proxy_config_bucket_public_access" {
  count                   = var.create_proxy_config_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.proxy_config_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "envoy_config_upload" {
  count        = var.create_proxy_config_bucket && var.envoy_config_content != "" ? 1 : 0
  bucket       = aws_s3_bucket.proxy_config_bucket[0].id
  key          = "envoy/envoy.yaml"
  content      = var.envoy_config_content
  content_type = "application/x-yaml"
  tags         = var.tags
}

resource "null_resource" "squid_config_upload" {
  count = var.create_proxy_config_bucket && var.squid_config_files_path != "" ? 1 : 0
  triggers = { dir_content_hash = timestamp() } # Placeholder
  provisioner "local-exec" { command = "aws s3 sync ${var.squid_config_files_path} s3://${aws_s3_bucket.proxy_config_bucket[0].id}/squid/ --delete" } # Sync to /squid/ prefix
  depends_on = [aws_s3_bucket.proxy_config_bucket]
}

resource "aws_s3_bucket" "squid_logs_bucket" {
  count  = var.create_squid_logs_bucket ? 1 : 0
  bucket = "${var.squid_logs_bucket_name_suffix}-${var.aws_account_id}-${var.aws_region}"
  tags   = var.tags
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "squid_logs_bucket_public_access" {
  count                   = var.create_squid_logs_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.squid_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "loki_logs_bucket" {
  count  = var.create_loki_logs_bucket ? 1 : 0
  bucket = "${var.loki_logs_bucket_name_suffix}-${var.aws_account_id}-${var.aws_region}"
  tags   = var.tags
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "loki_logs_bucket_public_access" {
  count                   = var.create_loki_logs_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.loki_logs_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Keymanager S3 Bucket ---
resource "aws_s3_bucket" "keymanager_env_bucket" {
  count  = var.create_keymanager_env_bucket ? 1 : 0
  bucket = "${var.keymanager_env_bucket_name_suffix}-${var.aws_account_id}-${var.aws_region}"
  tags   = var.tags
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "keymanager_env_bucket_public_access" {
  count                   = var.create_keymanager_env_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.keymanager_env_bucket[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "keymanager_env_bucket_encryption" {
  count  = var.create_keymanager_env_bucket && var.keymanager_kms_key_arn_for_bucket_encryption != null ? 1 : 0
  bucket = aws_s3_bucket.keymanager_env_bucket[0].bucket
  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = var.keymanager_kms_key_arn_for_bucket_encryption
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_policy" "keymanager_env_bucket_ssl" {
  count  = var.create_keymanager_env_bucket ? 1 : 0
  bucket = aws_s3_bucket.keymanager_env_bucket[0].id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Sid = "AllowSSLRequestsOnly", Effect = "Deny", Principal = "*", Action = "s3:*", Resource = [aws_s3_bucket.keymanager_env_bucket[0].arn, "${aws_s3_bucket.keymanager_env_bucket[0].arn}/*"], Condition = { Bool = { "aws:SecureTransport" = "false" } } }] })
}
