# Lambda function
resource "aws_lambda_function" "kms_encrypt" {
  filename         = "${path.module}/lambda/encryption.zip"
  function_name    = "${var.stack_name}-kms-encrypt"
  role             = aws_iam_role.kms_lambda.arn
  handler          = "index.lambda_handler"
  source_code_hash = data.archive_file.lambda_encryption.output_base64sha256
  runtime          = "python3.9"
  timeout          = 900

  environment {
    variables = {
      SECRET_MANAGER_ARN = aws_secretsmanager_secret.hyperswitch.arn
    }
  }
}

# Package the Lambda code
data "archive_file" "lambda_encryption" {
  type        = "zip"
  output_path = "${path.module}/lambda/encryption.zip"

  source {
    content  = file("${path.module}/lambda/encryption.py")
    filename = "index.py"
  }
}

resource "aws_lambda_invocation" "kms_encrypt" {
  function_name = aws_lambda_function.kms_encrypt.function_name

  input = jsonencode({
    RequestType = "Create"
    ResourceProperties = {
      Trigger = aws_secretsmanager_secret_version.hyperswitch.version_id, # Forces re-run if secrets change
    }
  })

  depends_on = [
    aws_secretsmanager_secret_version.hyperswitch,
    aws_lambda_function.kms_encrypt
  ]
}
