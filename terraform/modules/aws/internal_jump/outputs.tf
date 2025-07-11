output "instance_id" {
  description = "ID of the internal jump host instance"
  value       = aws_instance.internal_jump.id
}

output "instance_private_ip" {
  description = "Private IP address of the internal jump host"
  value       = aws_instance.internal_jump.private_ip
}

output "security_group_id" {
  description = "ID of the internal jump host security group"
  value       = aws_security_group.internal_jump.id
}

output "iam_role_arn" {
  description = "ARN of the internal jump host IAM role"
  value       = aws_iam_role.internal_jump.arn
}

output "iam_role_name" {
  description = "Name of the internal jump host IAM role"
  value       = aws_iam_role.internal_jump.name
}