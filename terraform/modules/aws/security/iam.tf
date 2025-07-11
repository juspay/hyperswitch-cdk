# KMS Lambda Role
resource "aws_iam_role" "kms_lambda" {
  name = "${var.stack_name}-kms-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}


# KMS Lambda Policy
resource "aws_iam_role_policy" "lambda_encryption_policy" {
  name = "${var.stack_name}-lambda-encryption-policy"
  role = aws_iam_role.kms_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "SecretsManagerAccess"
        Effect   = "Allow"
        Action   = ["secretsmanager:*"]
        Resource = ["*"]
      },
      {
        Sid      = "KMSAccess"
        Effect   = "Allow"
        Action   = ["kms:*"]
        Resource = [aws_kms_key.hyperswitch_kms_key.arn]
      },
      {
        Sid      = "SSMAccess"
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = ["*"]
      },
      {
        Sid    = "CloudWatchLogsAccess"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = [
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.stack_name}-kms-encrypt",
          "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.stack_name}-kms-encrypt:*"
        ]
      }
    ]
  })
}
