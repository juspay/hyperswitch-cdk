# Outputs
output "squid_pipeline_arn" {
  value = aws_imagebuilder_image_pipeline.squid_pipeline.arn
}

output "envoy_pipeline_arn" {
  value = aws_imagebuilder_image_pipeline.envoy_pipeline.arn
}

output "base_pipeline_arn" {
  value = aws_imagebuilder_image_pipeline.base_pipeline.arn
}

output "vpc_id" {
  value = aws_vpc.imagebuilder_vpc.id
}

output "lambda_function_name" {
  value = aws_lambda_function.ib_start_lambda.function_name
}
