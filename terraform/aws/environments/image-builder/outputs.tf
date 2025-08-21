output "vpc_id" {
  description = "ID of the Image Builder VPC"
  value       = aws_vpc.imagebuilder_vpc.id
}

output "squid_pipeline_arn" {
  description = "ARN of the Squid image pipeline"
  value       = aws_imagebuilder_image_pipeline.squid_pipeline.arn
}

output "envoy_pipeline_arn" {
  description = "ARN of the Envoy image pipeline"
  value       = aws_imagebuilder_image_pipeline.envoy_pipeline.arn
}

output "base_pipeline_arn" {
  description = "ARN of the Base image pipeline"
  value       = aws_imagebuilder_image_pipeline.base_pipeline.arn
}

output "lambda_function_names" {
  description = "Names of the Lambda functions"
  value = {
    ib_start_lambda      = aws_lambda_function.ib_start_lambda.function_name
    record_ami_squid     = aws_lambda_function.record_ami_squid.function_name
    record_ami_envoy     = aws_lambda_function.record_ami_envoy.function_name
    record_ami_base      = aws_lambda_function.record_ami_base.function_name
  }
}