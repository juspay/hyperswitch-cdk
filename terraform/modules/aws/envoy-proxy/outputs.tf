output "envoy_asg_security_group_id" {
  description = "The ID of the Envoy ASG security group"
  value       = aws_security_group.envoy_sg.id
}