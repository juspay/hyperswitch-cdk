output "web_acl_arn" {
  description = "ARN of the WAF Web ACL"
  value       = aws_wafv2_web_acl.hyperswitch_waf.arn
}

output "web_acl_id" {
  description = "ID of the WAF Web ACL"
  value       = aws_wafv2_web_acl.hyperswitch_waf.id
}

output "web_acl_capacity" {
  description = "Current capacity of the WAF Web ACL"
  value       = aws_wafv2_web_acl.hyperswitch_waf.capacity
}