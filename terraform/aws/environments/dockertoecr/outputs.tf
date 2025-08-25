output "lambda_function_name" {
  description = "Name of the Lambda function that triggers CodeBuild"
  value       = aws_lambda_function.start_codebuild.function_name
}

output "codebuild_project_name" {
  description = "Name of the CodeBuild project for ECR image transfer"
  value       = aws_codebuild_project.ecr_image_transfer.name
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for CodeBuild logs"
  value       = aws_cloudwatch_log_group.codebuild_logs.name
}
