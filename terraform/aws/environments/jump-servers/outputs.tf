output "external_jump_instance_id" {
  value       = module.external_jump.instance_id
  description = "ID of the external jump server instance"
}

output "external_jump_private_ip" {
  value       = module.external_jump.private_ip
  description = "Private IP address of the external jump server"
}

output "external_jump_security_group_id" {
  value       = module.external_jump.security_group_id
  description = "Security group ID of the external jump server"
}

output "internal_jump_instance_id" {
  value       = module.internal_jump.instance_id
  description = "ID of the internal jump server instance"
}

output "internal_jump_private_ip" {
  value       = module.internal_jump.private_ip
  description = "Private IP address of the internal jump server"
}

output "internal_jump_security_group_id" {
  value       = module.internal_jump.security_group_id
  description = "Security group ID of the internal jump server"
}