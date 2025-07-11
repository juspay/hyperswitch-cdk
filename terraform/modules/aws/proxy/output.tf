output "envoy_asg_security_group_id" {
  description = "Security Group ID for Envoy ASG instances"
  value       = aws_security_group.envoy_sg.id
}

