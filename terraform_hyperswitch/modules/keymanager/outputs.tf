output "keymanager_rds_cluster_endpoint" {
  description = "Endpoint of the Keymanager RDS Aurora cluster."
  value       = aws_rds_cluster.keymanager_db[0].endpoint
  depends_on  = [aws_rds_cluster.keymanager_db]
}

output "keymanager_rds_cluster_id" {
  description = "ID of the Keymanager RDS Aurora cluster."
  value       = aws_rds_cluster.keymanager_db[0].id
  depends_on  = [aws_rds_cluster.keymanager_db]
}

output "keymanager_ec2_instance_id" {
  description = "ID of the Keymanager EC2 instance."
  value       = aws_instance.keymanager_ec2[0].id
  depends_on  = [aws_instance.keymanager_ec2]
}

output "keymanager_ec2_private_ip" {
  description = "Private IP of the Keymanager EC2 instance."
  value       = aws_instance.keymanager_ec2[0].private_ip
  depends_on  = [aws_instance.keymanager_ec2]
}

output "keymanager_ec2_security_group_id" {
  description = "Security Group ID of the Keymanager EC2 instance."
  value       = aws_security_group.keymanager_ec2_sg.id
}

output "keymanager_db_security_group_id" {
  description = "Security Group ID of the Keymanager RDS database."
  value       = aws_security_group.keymanager_db_sg.id
}

output "keymanager_env_s3_object_key" {
  description = "S3 object key for the Keymanager .env file."
  value       = local.env_file_s3_key
}
