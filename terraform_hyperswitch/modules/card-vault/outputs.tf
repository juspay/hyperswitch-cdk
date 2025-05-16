output "locker_rds_cluster_endpoint" {
  description = "Endpoint of the Locker RDS Aurora cluster."
  value       = aws_rds_cluster.locker_db[0].endpoint
  depends_on  = [aws_rds_cluster.locker_db]
}

output "locker_rds_cluster_id" {
  description = "ID of the Locker RDS Aurora cluster."
  value       = aws_rds_cluster.locker_db[0].id
  depends_on  = [aws_rds_cluster.locker_db]
}

output "locker_ec2_instance_id" {
  description = "ID of the Locker EC2 instance."
  value       = aws_instance.locker_ec2[0].id
  depends_on  = [aws_instance.locker_ec2]
}

output "locker_ec2_private_ip" {
  description = "Private IP of the Locker EC2 instance."
  value       = aws_instance.locker_ec2[0].private_ip
  depends_on  = [aws_instance.locker_ec2]
}

output "locker_ec2_security_group_id" {
  description = "Security Group ID of the Locker EC2 instance."
  value       = aws_security_group.locker_ec2_sg.id
}

output "locker_db_security_group_id" {
  description = "Security Group ID of the Locker RDS database."
  value       = aws_security_group.locker_db_sg.id
}

output "jump_host_public_ip" {
  description = "Public IP of the Locker jump host (if created)."
  value       = var.enable_jump_host ? aws_instance.jump_host[0].public_ip : null
  depends_on  = [aws_instance.jump_host]
}

output "jump_host_key_pair_name" {
  description = "Name of the key pair for the Locker jump host (if created)."
  value       = var.enable_jump_host ? aws_key_pair.jump_host_key[0].key_name : null
  depends_on  = [aws_key_pair.jump_host_key]
}

output "tenant_private_key_ssm_parameter_name" {
  description = "Name of the SSM parameter storing the tenant's private key."
  value       = aws_ssm_parameter.tenant_private_key[0].name
  depends_on  = [aws_ssm_parameter.tenant_private_key]
}

output "locker_public_key_ssm_parameter_name" {
  description = "Name of the SSM parameter storing the locker's public key."
  value       = aws_ssm_parameter.locker_public_key[0].name
  depends_on  = [aws_ssm_parameter.locker_public_key]
}
