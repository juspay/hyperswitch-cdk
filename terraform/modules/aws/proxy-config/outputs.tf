output "proxy_config_bucket_name" {
  description = "The name of the S3 bucket for proxy configurations"
  value       = aws_s3_bucket.proxy_config.bucket
}

output "proxy_config_bucket_arn" {
  description = "The ARN of the S3 bucket for proxy configurations"
  value       = aws_s3_bucket.proxy_config.arn
}