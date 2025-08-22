# CloudFront VPC Origin for Hyperswitch Internal ALB
resource "aws_cloudfront_vpc_origin" "hyperswitch_alb_vpc_origin" {
  vpc_origin_endpoint_config {
    name                   = "${var.stack_name}-hyperswitch-alb-vpc-origin"
    arn                    = aws_lb.hyperswitch_alb.arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-hyperswitch-alb-vpc-origin"
  })
}

resource "aws_cloudfront_distribution" "hyperswitch_cloudfront_distribution" {
  enabled = true
  comment = "Hyperswitch Internal ALB Distribution with VPC Origin"
  origin {
    domain_name = aws_cloudfront_vpc_origin.hyperswitch_alb_vpc_origin.id
    origin_id   = "${var.stack_name}-hyperswitch-alb-vpc-origin"

    vpc_origin_config {
      vpc_origin_id            = aws_cloudfront_vpc_origin.hyperswitch_alb_vpc_origin.id
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }
  }

  default_cache_behavior {
    target_origin_id = "${var.stack_name}-hyperswitch-alb-vpc-origin"

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
    Name = "${var.stack_name}-hyperswitch-alb-distribution"
  })
}

