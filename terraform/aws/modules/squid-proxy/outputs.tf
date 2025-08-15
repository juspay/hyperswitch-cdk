output "squid_asg_security_group_id" {
  description = "The ID of the Squid ASG security group"
  value       = aws_security_group.squid_asg_sg.id
}

output "squid_logs_bucket_name" {
  description = "The name of the S3 bucket for Squid logs"
  value       = aws_s3_bucket.squid_logs_bucket.bucket
}

output "squid_logs_bucket_arn" {
  description = "The ARN of the S3 bucket for Squid logs"
  value       = aws_s3_bucket.squid_logs_bucket.arn
}

output "squid_nlb_dns_name" {
  value       = aws_lb.squid_nlb.dns_name
  description = "DNS name of the Squid NLB"
}
