output "external_alb_security_group_id" {
  value       = aws_security_group.external_lb_sg.id
  description = "ID of the External ALB Security Group"
}

output "external_alb_distribution_domain_name" {
  value       = aws_cloudfront_distribution.external_alb_distribution.domain_name
  description = "The domain name of the external ALB CloudFront distribution"
}

output "envoy_target_group_arn" {
  value       = aws_lb_target_group.envoy_tg.arn
  description = "ARN of the Envoy target group"
}

output "cloudfront_ip_ranges" {
  value       = data.aws_ip_ranges.cloudfront.cidr_blocks
  description = "CloudFront IP ranges for security group rules"
}
