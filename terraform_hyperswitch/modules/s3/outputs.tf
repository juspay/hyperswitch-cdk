output "rds_schema_bucket_id" {
  description = "ID of the S3 bucket for RDS standalone schema."
  value       = var.create_rds_schema_bucket ? aws_s3_bucket.rds_schema_bucket[0].id : null
  depends_on  = [aws_s3_bucket.rds_schema_bucket]
}

output "rds_schema_bucket_arn" {
  description = "ARN of the S3 bucket for RDS standalone schema."
  value       = var.create_rds_schema_bucket ? aws_s3_bucket.rds_schema_bucket[0].arn : null
  depends_on  = [aws_s3_bucket.rds_schema_bucket]
}

output "locker_env_bucket_id" {
  description = "ID of the S3 bucket for Locker environment file."
  value       = var.create_locker_env_bucket ? aws_s3_bucket.locker_env_bucket[0].id : null
  depends_on  = [aws_s3_bucket.locker_env_bucket]
}

output "locker_env_bucket_arn" {
  description = "ARN of the S3 bucket for Locker environment file."
  value       = var.create_locker_env_bucket ? aws_s3_bucket.locker_env_bucket[0].arn : null
  depends_on  = [aws_s3_bucket.locker_env_bucket]
}

output "sdk_bucket_id" {
  description = "ID of the S3 bucket for Hyperswitch SDK assets."
  value       = var.create_sdk_bucket ? aws_s3_bucket.sdk_bucket[0].id : null
  depends_on  = [aws_s3_bucket.sdk_bucket]
}

output "sdk_bucket_arn" {
  description = "ARN of the S3 bucket for Hyperswitch SDK assets."
  value       = var.create_sdk_bucket ? aws_s3_bucket.sdk_bucket[0].arn : null
  depends_on  = [aws_s3_bucket.sdk_bucket]
}

output "sdk_bucket_website_endpoint" {
  description = "Website endpoint for the SDK S3 bucket."
  value       = var.create_sdk_bucket ? aws_s3_bucket.sdk_bucket[0].bucket_regional_domain_name : null
  depends_on  = [aws_s3_bucket.sdk_bucket]
}

output "sdk_oai_arn" {
  description = "ARN of the CloudFront Origin Access Identity for the SDK bucket."
  value       = var.create_sdk_bucket ? aws_cloudfront_origin_access_identity.sdk_oai[0].iam_arn : null
  depends_on  = [aws_cloudfront_origin_access_identity.sdk_oai]
}

output "proxy_config_bucket_id" {
  description = "ID of the S3 bucket for proxy configurations."
  value       = var.create_proxy_config_bucket ? aws_s3_bucket.proxy_config_bucket[0].id : null
  depends_on  = [aws_s3_bucket.proxy_config_bucket]
}

output "proxy_config_bucket_arn" {
  description = "ARN of the S3 bucket for proxy configurations."
  value       = var.create_proxy_config_bucket ? aws_s3_bucket.proxy_config_bucket[0].arn : null
  depends_on  = [aws_s3_bucket.proxy_config_bucket]
}

output "squid_logs_bucket_id" {
  description = "ID of the S3 bucket for Squid proxy logs."
  value       = var.create_squid_logs_bucket ? aws_s3_bucket.squid_logs_bucket[0].id : null
  depends_on  = [aws_s3_bucket.squid_logs_bucket]
}

output "squid_logs_bucket_arn" {
  description = "ARN of the S3 bucket for Squid proxy logs."
  value       = var.create_squid_logs_bucket ? aws_s3_bucket.squid_logs_bucket[0].arn : null
  depends_on  = [aws_s3_bucket.squid_logs_bucket]
}

output "loki_logs_bucket_id" {
  description = "ID of the S3 bucket for Loki log storage."
  value       = var.create_loki_logs_bucket ? aws_s3_bucket.loki_logs_bucket[0].id : null
  depends_on  = [aws_s3_bucket.loki_logs_bucket]
}

output "loki_logs_bucket_arn" {
  description = "ARN of the S3 bucket for Loki log storage."
  value       = var.create_loki_logs_bucket ? aws_s3_bucket.loki_logs_bucket[0].arn : null
  depends_on  = [aws_s3_bucket.loki_logs_bucket]
}

output "keymanager_env_bucket_id" {
  description = "ID of the S3 bucket for Keymanager environment file."
  value       = var.create_keymanager_env_bucket ? aws_s3_bucket.keymanager_env_bucket[0].id : null
  depends_on  = [aws_s3_bucket.keymanager_env_bucket]
}

output "keymanager_env_bucket_arn" {
  description = "ARN of the S3 bucket for Keymanager environment file."
  value       = var.create_keymanager_env_bucket ? aws_s3_bucket.keymanager_env_bucket[0].arn : null
  depends_on  = [aws_s3_bucket.keymanager_env_bucket]
}
