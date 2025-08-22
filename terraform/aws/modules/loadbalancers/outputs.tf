output "hyperswitch_alb_security_group_id" {
  value       = aws_security_group.hyperswitch_alb_sg.id
  description = "ID of the Hyperswitch Internal ALB Security Group"
}

output "hyperswitch_cloudfront_distribution_domain_name" {
  value       = aws_cloudfront_distribution.hyperswitch_cloudfront_distribution.domain_name
  description = "The domain name of the Hyperswitch ALB CloudFront distribution with VPC origin"
}

output "envoy_target_group_arn" {
  value       = aws_lb_target_group.envoy_tg.arn
  description = "ARN of the Hyperswitch Envoy target group"
}

output "hyperswitch_alb_vpc_origin_id" {
  value       = aws_cloudfront_vpc_origin.hyperswitch_alb_vpc_origin.id
  description = "ID of the CloudFront VPC origin for Hyperswitch ALB"
}

output "hyperswitch_alb_arn" {
  value       = aws_lb.hyperswitch_alb.arn
  description = "ARN of the Hyperswitch Internal ALB"
}
