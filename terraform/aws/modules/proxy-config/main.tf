# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# S3 Bucket for Proxy Configurations (shared between Envoy and Squid)
resource "aws_s3_bucket" "proxy_config" {
  bucket = "${var.stack_name}-proxy-configurations-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-proxy-configurations-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  })
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "proxy_config" {
  bucket = aws_s3_bucket.proxy_config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "proxy_config" {
  bucket = aws_s3_bucket.proxy_config.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# S3 Bucket Policy for Proxy Configurations
resource "aws_s3_bucket_policy" "proxy_config_policy" {
  bucket = aws_s3_bucket.proxy_config.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "AllowVpcEndpointAccess",
        Effect    = "Allow",
        Principal = "*",
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ],
        Resource = [
          aws_s3_bucket.proxy_config.arn,
          "${aws_s3_bucket.proxy_config.arn}/*"
        ],
        Condition = {
          StringEquals = {
            "aws:sourceVpc" = var.vpc_id
          }
        }
      },
      {
        Sid    = "AllowCDKDeployment",
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        },
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ],
        Resource = [
          aws_s3_bucket.proxy_config.arn,
          "${aws_s3_bucket.proxy_config.arn}/*"
        ]
      }
    ]
  })
}