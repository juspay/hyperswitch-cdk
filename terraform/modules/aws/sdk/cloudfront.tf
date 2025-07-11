# ==========================================================
#              Cloudfront Distribution for SDK
# ==========================================================

resource "aws_cloudfront_distribution" "sdk_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Hyperswitch SDK Distribution"
  default_root_object = "index.html"

  # Origin configuration for S3
  origin {
    domain_name = aws_s3_bucket.hyperswitch_sdk.bucket_regional_domain_name
    origin_id   = "S3-${aws_s3_bucket.hyperswitch_sdk.id}"

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.sdk_oai.cloudfront_access_identity_path
    }
  }

  # Default cache behavior
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.hyperswitch_sdk.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Additional cache behavior for /* pattern
  ordered_cache_behavior {
    path_pattern     = "/*"
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.hyperswitch_sdk.id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Viewer certificate
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(
    var.common_tags, {
      Name = "${var.stack_name}-sdk-distribution"
    }
  )
  depends_on = [aws_s3_bucket.hyperswitch_sdk]
}
