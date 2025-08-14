resource "aws_cloudfront_distribution" "external_alb_distribution" {
  enabled = true
  comment = "Hyperswitch External ALB Distribution"
  origin {
    domain_name = aws_lb.external_alb.dns_name
    origin_id   = "${var.stack_name}-external-alb-origin"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only" # CloudFront → ALB uses HTTP
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id = "${var.stack_name}-external-alb-origin"

    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad" # Managed-CachingDisabled
    origin_request_policy_id = "33f36d7e-f396-46d9-90e0-52428a34d9dc" # Managed-AllViewer
  }

  # Restrictions
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  # Viewer certificate (CloudFront default)
  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-external-alb-distribution"
  })
}

