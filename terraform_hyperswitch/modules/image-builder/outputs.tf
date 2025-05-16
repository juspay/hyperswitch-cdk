output "squid_image_pipeline_arn" {
  description = "ARN of the Squid Image Pipeline."
  value       = aws_imagebuilder_image_pipeline.squid_pipeline.arn
}

output "envoy_image_pipeline_arn" {
  description = "ARN of the Envoy Image Pipeline."
  value       = aws_imagebuilder_image_pipeline.envoy_pipeline.arn
}

output "base_image_pipeline_arn" {
  description = "ARN of the Base Image Pipeline."
  value       = aws_imagebuilder_image_pipeline.base_pipeline.arn
}

output "squid_ami_ssm_parameter_name_output" {
  description = "Name of the SSM parameter where the Squid AMI ID is stored."
  value       = var.squid_ami_ssm_parameter_name
}

output "envoy_ami_ssm_parameter_name_output" {
  description = "Name of the SSM parameter where the Envoy AMI ID is stored."
  value       = var.envoy_ami_ssm_parameter_name
}

output "base_ami_ssm_parameter_name_output" {
  description = "Name of the SSM parameter where the Base AMI ID is stored."
  value       = var.base_ami_ssm_parameter_name
}

output "sns_topic_squid_arn" {
  description = "ARN of the SNS topic for Squid Image Builder notifications."
  value       = aws_sns_topic.squid_notification_topic.arn
}

output "sns_topic_envoy_arn" {
  description = "ARN of the SNS topic for Envoy Image Builder notifications."
  value       = aws_sns_topic.envoy_notification_topic.arn
}

output "sns_topic_base_arn" {
  description = "ARN of the SNS topic for Base Image Builder notifications."
  value       = aws_sns_topic.base_notification_topic.arn
}
