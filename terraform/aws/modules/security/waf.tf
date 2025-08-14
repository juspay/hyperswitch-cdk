# ==========================================================
#                     WAF Configuration
# ==========================================================

resource "aws_wafv2_web_acl" "hyperswitch_waf" {
  name        = "${var.stack_name}-web-acl"
  scope       = "REGIONAL"
  description = "WAF for Hyperswitch application"

  default_action {
    allow {}
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "WebACL"
    sampled_requests_enabled   = true
  }

  rule {
    name     = "allow_merchant_admin"
    priority = 0
    action {
      allow {}
    }
    statement {
      byte_match_statement {
        field_to_match {
          uri_path {}
        }
        positional_constraint = "ENDS_WITH"
        search_string         = "merchant_admin"
        text_transformation {
          type     = "NONE"
          priority = 0
        }

      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow_merchant_admin"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "health_status"
    priority = 1

    action {
      allow {}
    }

    statement {
      byte_match_statement {
        field_to_match {
          single_header {
            name = "x-hyperswitch-betterstack"
          }
        }

        positional_constraint = "EXACTLY"
        search_string         = "Betterstack-ironman"

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "health_status"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "allow_pingdom"
    priority = 2

    action {
      allow {}
    }

    statement {
      byte_match_statement {
        field_to_match {
          single_header {
            name = "user-agent"
          }
        }

        positional_constraint = "EXACTLY"
        search_string         = "Pingdom.com_bot_version_1.4_(http://www.pingdom.com/)"

        text_transformation {
          priority = 0
          type     = "NONE"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "allow_pingdom"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
    priority = 3

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesKnownBadInputsRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "JavaDeserializationRCE_BODY"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "JavaDeserializationRCE_URIPATH"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "JavaDeserializationRCE_QUERYSTRING"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "JavaDeserializationRCE_HEADER"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "Host_localhost_HEADER"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "PROPFIND_METHOD"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "ExploitablePaths_URIPATH"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "Log4JRCE_QUERYSTRING"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "Log4JRCE_BODY"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "Log4JRCE_URIPATH"
          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "Log4JRCE_HEADER"
          action_to_use {
            block {}
          }
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesKnownBadInputsRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 4

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "NoUserAgent_HEADER"

          action_to_use {
            allow {}
          }
        }

        rule_action_override {
          name = "UserAgent_BadBots_HEADER"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "SizeRestrictions_QUERYSTRING"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "SizeRestrictions_Cookie_HEADER"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "SizeRestrictions_BODY"

          action_to_use {
            allow {}
          }
        }

        rule_action_override {
          name = "SizeRestrictions_URIPATH"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "EC2MetaDataSSRF_BODY"

          action_to_use {
            allow {}
          }
        }

        rule_action_override {
          name = "EC2MetaDataSSRF_COOKIE"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "EC2MetaDataSSRF_URIPATH"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "GenericLFI_URIPATH"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "GenericLFI_QUERYARGUMENTS"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "EC2MetaDataSSRF_QUERYARGUMENTS"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "GenericLFI_BODY"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "RestrictedExtensions_URIPATH"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "RestrictedExtensions_QUERYARGUMENTS"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "GenericRFI_QUERYARGUMENTS"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "GenericRFI_BODY"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "GenericRFI_URIPATH"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "CrossSiteScripting_COOKIE"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "CrossSiteScripting_QUERYARGUMENTS"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "CrossSiteScripting_BODY"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "CrossSiteScripting_URIPATH"

          action_to_use {
            block {}
          }
        }

      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesSQLiRuleSet"
    priority = 5

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesSQLiRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "SQLi_BODY"

          action_to_use {
            allow {}
          }
        }

        rule_action_override {
          name = "SQLiExtendedPatterns_QUERYARGUMENTS"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "SQLi_QUERYARGUMENTS"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "SQLi_COOKIE"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "SQLi_URIPATH"

          action_to_use {
            block {}
          }
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesSQLiRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAdminProtectionRuleSet"
    priority = 6

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAdminProtectionRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "AdminProtection_URIPATH"

          action_to_use {
            block {}
          }
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAdminProtectionRuleSet"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesAmazonIpReputationList"
    priority = 7

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesAmazonIpReputationList"
        vendor_name = "AWS"

        rule_action_override {
          name = "AWSManagedIPDDoSList"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "AWSManagedIPReputationList"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "AWSManagedReconnaissanceList"

          action_to_use {
            block {}
          }
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesAmazonIpReputationList"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "AWS-AWSManagedRulesLinuxRuleSet"
    priority = 8

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesLinuxRuleSet"
        vendor_name = "AWS"

        rule_action_override {
          name = "LFI_URIPATH"

          action_to_use {
            block {}
          }
        }

        rule_action_override {
          name = "LFI_QUERYSTRING"

          action_to_use {
            block {}
          }
        }
      }
    }

    override_action {
      none {}
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWS-AWSManagedRulesLinuxRuleSet"
      sampled_requests_enabled   = true
    }
  }

}

# ==========================================================
#              S3 Bucket COnfiguration for logs
# ==========================================================

# S3 Bucket for Server Access Logs
resource "aws_s3_bucket" "server_access_logs" {
  bucket = "serveraccesslogs-${var.stack_name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-server-access-logs"
    }
  )
}

resource "aws_s3_bucket_ownership_controls" "server_access_logs" {
  bucket = aws_s3_bucket.server_access_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "server_access_logs" {
  bucket = aws_s3_bucket.server_access_logs.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_ownership_controls.server_access_logs,
    aws_s3_bucket_public_access_block.server_access_logs,
  ]
}

resource "aws_s3_bucket_public_access_block" "server_access_logs" {
  bucket = aws_s3_bucket.server_access_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy for Server Access Logs
resource "aws_s3_bucket_policy" "server_access_logs" {
  bucket = aws_s3_bucket.server_access_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "logging.s3.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.server_access_logs.arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
        }
      },
      {
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.server_access_logs.arn,
          "${aws_s3_bucket.server_access_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# S3 Bucket for WAF Logs
resource "aws_s3_bucket" "waf_logs" {
  bucket = "aws-waf-logs-${var.stack_name}-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-waf-logs"
    }
  )
}

resource "aws_s3_bucket_ownership_controls" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_acl" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_ownership_controls.waf_logs,
    aws_s3_bucket_public_access_block.waf_logs,
  ]
}

resource "aws_s3_bucket_public_access_block" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_logging" "waf_logs" {
  bucket        = aws_s3_bucket.waf_logs.id
  target_bucket = aws_s3_bucket.server_access_logs.id
  target_prefix = "AWSLogs/"

  target_object_key_format {
    simple_prefix {}
  }
}

resource "aws_s3_bucket_policy" "waf_logs" {
  bucket = aws_s3_bucket.waf_logs.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:PutObject"
        Resource = "${aws_s3_bucket.waf_logs.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Effect = "Allow"
        Principal = {
          Service = "delivery.logs.amazonaws.com"
        }
        Action   = "s3:GetBucketAcl"
        Resource = aws_s3_bucket.waf_logs.arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          }
          ArnLike = {
            "aws:SourceArn" = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:*"
          }
        }
      },
      {
        Effect = "Deny"
        Principal = {
          AWS = "*"
        }
        Action = "s3:*"
        Resource = [
          aws_s3_bucket.waf_logs.arn,
          "${aws_s3_bucket.waf_logs.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" = "false"
          }
        }
      }
    ]
  })
}

# WAF Logging Configuration
resource "aws_wafv2_web_acl_logging_configuration" "hyperswitch_waf_logging" {
  resource_arn = aws_wafv2_web_acl.hyperswitch_waf.arn

  log_destination_configs = [
    aws_s3_bucket.waf_logs.arn
  ]
}
