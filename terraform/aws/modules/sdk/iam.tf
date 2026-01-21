# ==========================================================
#              Cloudfront Configuration for SDK
# ==========================================================

resource "aws_cloudfront_origin_access_identity" "sdk_oai" {
  comment = "OAI for Hyperswitch SDK bucket"
}

resource "aws_s3_bucket_policy" "sdk_bucket_policy" {
  bucket = aws_s3_bucket.hyperswitch_sdk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontOAI"
        Effect = "Allow"
        Principal = {
          AWS = aws_cloudfront_origin_access_identity.sdk_oai.iam_arn
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.hyperswitch_sdk.arn}/*"
      },
      {
        Sid    = "AllowCodeBuildAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.sdk_build_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.hyperswitch_sdk.arn,
          "${aws_s3_bucket.hyperswitch_sdk.arn}/*"
        ]
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.hyperswitch_sdk]
}

# ==========================================================
#                CodeBuild Project for SDK
# ==========================================================

# IAM Role for CodeBuild
resource "aws_iam_role" "sdk_build_role" {
  name = "${var.stack_name}-sdk-build-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Policy for SDK Build
resource "aws_iam_role_policy" "sdk_build_policy" {
  name = "${var.stack_name}-sdk-build-policy"
  role = aws_iam_role.sdk_build_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elbv2:DescribeLoadBalancers",
          "cloudfront:ListDistributions"
        ]
        Resource = ["*"]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [aws_cloudwatch_log_group.codebuild_logs.arn,
        "${aws_cloudwatch_log_group.codebuild_logs.arn}:*"]
      }
    ]
  })
}

# IAM Role for Lambda
resource "aws_iam_role" "sdk_assets_upload_lambda_role" {
  name = "${var.stack_name}-sdk-assets-upload-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "sdk_assets_upload_lambda_policy" {
  name = "${var.stack_name}-sdk-assets-upload-lambda-policy"
  role = aws_iam_role.sdk_assets_upload_lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "codebuild:StartBuild"
        ],
        Resource = [aws_codebuild_project.hyperswitch_sdk.arn]
      },
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource = ["*"]
      }
    ]
  })
}

