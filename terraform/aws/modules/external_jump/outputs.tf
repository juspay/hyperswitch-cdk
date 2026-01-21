output "instance_id" {
  description = "ID of the external jump host instance"
  value       = aws_instance.external_jump.id
}

output "instance_private_ip" {
  description = "Private IP address of the external jump host"
  value       = aws_instance.external_jump.private_ip
}

output "instance_public_ip" {
  description = "Public IP address of the external jump host"
  value       = aws_instance.external_jump.public_ip
}

output "security_group_id" {
  description = "ID of the external jump host security group"
  value       = aws_security_group.external_jump.id
}

output "iam_role_arn" {
  description = "ARN of the external jump host IAM role"
  value       = aws_iam_role.external_jump.arn
}

output "iam_role_name" {
  description = "Name of the external jump host IAM role"
  value       = aws_iam_role.external_jump.name
}