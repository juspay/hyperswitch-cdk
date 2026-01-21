
# ==========================================================
#                      Initialization
# ==========================================================

terraform {
  required_version = "~> 1.12.2"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Provider configurations
provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  common_tags = {
    Stack       = "Hyperswitch"
    StackName   = var.stack_name
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "ECR Image Transfer"
  }
}

# ==========================================================
#                 Codebuild and Lambda
# ==========================================================

resource "aws_codebuild_project" "ecr_image_transfer" {
  name         = "${var.stack_name}-ecr-image-transfer"
  service_role = aws_iam_role.ecr_role.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = false

    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }

    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = data.aws_region.current.name
    }
  }

  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/dependencies/buildspec.yml")
  }

  logs_config {
    cloudwatch_logs {
      group_name  = aws_cloudwatch_log_group.codebuild_logs.name
      stream_name = "ecr-image-transfer-log-stream"
    }
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.stack_name}-ecr-image-transfer"
    }
  )
}

resource "aws_cloudwatch_log_group" "codebuild_logs" {
  name              = "/aws/codebuild/${var.stack_name}-ecr-image-transfer"
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

resource "aws_lambda_function" "start_codebuild" {
  filename         = data.archive_file.lambda_codebuild.output_path
  function_name    = "${var.stack_name}-ecr-image-transfer-lambda"
  handler          = "index.lambda_handler"
  runtime          = "python3.9"
  timeout          = 900
  source_code_hash = data.archive_file.lambda_codebuild.output_base64sha256
  role             = aws_iam_role.trigger_codebuild_role.arn

  environment {
    variables = {
      PROJECT_NAME = aws_codebuild_project.ecr_image_transfer.name
    }
  }
}

# Lambda Invocation
resource "aws_lambda_invocation" "start_codebuild" {
  function_name = aws_lambda_function.start_codebuild.function_name

  input = jsonencode({
    RequestType        = "Create"
    ResourceProperties = {}
  })

  lifecycle {
    # Trigger when Lambda or buildspec changes
    replace_triggered_by = [
      aws_lambda_function.start_codebuild.source_code_hash,
      aws_codebuild_project.ecr_image_transfer.source[0].buildspec
    ]
  }
}


# ==========================================================
#                 IAM Roles and Policies
# ==========================================================

# ECR Role for CodeBuild
resource "aws_iam_role" "ecr_role" {
  name = "${var.stack_name}-ecr-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
        Effect = "Allow"
      }
    ]
  })
}

# Lambda Role for ECR Image Transfer
resource "aws_iam_role" "trigger_codebuild_role" {
  name = "${var.stack_name}-trigger-codebuild-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}



# ECR Policy for CodeBuild
resource "aws_iam_role_policy" "ecr_policy" {
  name = "${var.stack_name}-ecr-policy"
  role = aws_iam_role.ecr_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:CreateRepository",
          "ecr:CompleteLayerUpload",
          "ecr:GetAuthorizationToken",
          "ecr:UploadLayerPart",
          "ecr:InitiateLayerUpload",
          "ecr:BatchCheckLayerAvailability",
          "ecr:PutImage"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          aws_cloudwatch_log_group.codebuild_logs.arn,
          "${aws_cloudwatch_log_group.codebuild_logs.arn}:*"
        ]
      }
    ]
  })
}

# ECR Image Transfer Lambda Policy
resource "aws_iam_role_policy" "trigger_codebuild_role_policy" {
  name = "ECRImageTransferLambdaPolicy"
  role = aws_iam_role.trigger_codebuild_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "codebuild:StartBuild"
        ]
        Resource = aws_codebuild_project.ecr_image_transfer.arn
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}
