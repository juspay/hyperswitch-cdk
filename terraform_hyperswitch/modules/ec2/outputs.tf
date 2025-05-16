output "instance_id" {
  description = "ID of the EC2 instance."
  value       = aws_instance.this[0].id
  depends_on  = [aws_instance.this]
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance."
  value       = aws_instance.this[0].public_ip
  depends_on  = [aws_instance.this]
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance."
  value       = aws_instance.this[0].private_ip
  depends_on  = [aws_instance.this]
}

output "instance_arn" {
  description = "ARN of the EC2 instance."
  value       = aws_instance.this[0].arn
  depends_on  = [aws_instance.this]
}

output "security_group_id" {
  description = "ID of the security group associated with/created for the EC2 instance."
  value       = local.final_security_group_id # Using local variable that decides between new or existing SG
}

output "created_key_pair_name" {
  description = "Name of the EC2 key pair created by this module (if any)."
  value       = var.create_new_key_pair && var.key_pair_name == null ? aws_key_pair.this[0].key_name : null
  depends_on  = [aws_key_pair.this]
}

output "created_key_pair_id" {
  description = "ID of the EC2 key pair created by this module (if any)."
  value       = var.create_new_key_pair && var.key_pair_name == null ? aws_key_pair.this[0].id : null
  depends_on  = [aws_key_pair.this]
}
