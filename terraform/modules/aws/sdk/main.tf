# AWS Current Region
data "aws_region" "current" {}

# AWS Account ID
data "aws_caller_identity" "current" {}

# ==========================================================
#                    S3 Bucket for SDK
# ==========================================================

resource "aws_s3_bucket" "hyperswitch_sdk" {
  bucket = "${var.stack_name}-sdk-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-waf-logs"
    }
  )
}

resource "aws_s3_bucket_ownership_controls" "hyperswitch_sdk" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "hyperswitch_sdk" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_acl" "hyperswitch_sdk" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_ownership_controls.hyperswitch_sdk,
    aws_s3_bucket_public_access_block.hyperswitch_sdk,
  ]
}

resource "aws_s3_bucket_cors_configuration" "hyperswitch_sdk" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id

  cors_rule {
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    allowed_headers = ["*"]
    max_age_seconds = 3000
  }

}

# ==========================================================
#                CodeBuild Project for SDK
# ==========================================================

# CodeBuild Project
resource "aws_codebuild_project" "hyperswitch_sdk" {
  name         = "${var.stack_name}-sdk-codebuild"
  service_role = aws_iam_role.sdk_build_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"

    environment_variable {
      name  = "sdkBucket"
      value = aws_s3_bucket.hyperswitch_sdk.bucket
      type  = "PLAINTEXT"
    }

    environment_variable {
      name  = "envSdkUrl"
      value = "https://${aws_cloudfront_distribution.sdk_distribution.domain_name}"
      type  = "PLAINTEXT"
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = <<-EOT
      version: 0.2
      phases:
        install:
          commands:
            - 'BACKEND_URL=${var.external_alb_distribution_domain_name}'
            - 'export ENV_BACKEND_URL="https://$${BACKEND_URL}/api"'
            - "git clone --branch v${var.sdk_version} https://github.com/juspay/hyperswitch-web"
            - "cd hyperswitch-web"
            - "curl -L https://raw.githubusercontent.com/tj/n/master/bin/n -o n"
            - "chmod +x n"
            - "./n 18"
            - "npm install"
            - "npm run re:build"
        build:
          commands: "ENV_SDK_URL=$envSdkUrl npm run build:sandbox"
        post_build:
          commands:
            - "aws s3 cp --recursive dist/sandbox/ s3://$sdkBucket/web/${var.sdk_version}/"
    EOT
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild_logs.name
      stream_name = "sdk-build-logs"
    }
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-sdk-codebuild"
    }
  )
}

resource "aws_cloudwatch_log_group" "codebuild_logs" {
  name              = "/aws/codebuild/${var.stack_name}-sdk-build-logs"
  retention_in_days = var.log_retention_days
}

# Package the Lambda code
data "archive_file" "lambda_codebuild" {
  type        = "zip"
  output_path = "${path.module}/dependencies/start_build.zip"

  source {
    content  = file("${path.module}/dependencies/start_build.py")
    filename = "index.py"
  }
}

# Lambda Function
resource "aws_lambda_function" "sdk_assets_upload" {
  filename         = data.archive_file.lambda_codebuild.output_path
  function_name    = "${var.stack_name}-sdk-assets-upload"
  role             = aws_iam_role.sdk_assets_upload_lambda_role.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_codebuild.output_base64sha256
  runtime          = "python3.9"
  timeout          = 900

  environment {
    variables = {
      PROJECT_NAME = aws_codebuild_project.hyperswitch_sdk.name
    }
  }
}

# Lambda Invocation
resource "aws_lambda_invocation" "sdk_assets_upload" {
  function_name = aws_lambda_function.sdk_assets_upload.function_name

  input = jsonencode({
    RequestType        = "Create"
    ResourceProperties = {}
  })

  lifecycle {
    # Only trigger on creation
    replace_triggered_by = [
      aws_lambda_function.sdk_assets_upload.source_code_hash
    ]
  }
}
