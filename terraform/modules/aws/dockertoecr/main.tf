data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

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
    var.common_tags,
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

  vpc_config {
    subnet_ids         = var.subnet_ids["isolated"]
    security_group_ids = [aws_security_group.lambda.id]
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
    # Only trigger on creation
    replace_triggered_by = [
      aws_lambda_function.start_codebuild.source_code_hash
    ]
  }
}
