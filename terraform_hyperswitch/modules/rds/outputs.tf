output "db_instance_id" {
  description = "The instance identifier of the standalone RDS instance."
  value       = var.is_standalone_deployment ? aws_db_instance.standalone_db[0].id : null
}

output "db_instance_address" {
  description = "The address of the standalone RDS instance."
  value       = var.is_standalone_deployment ? aws_db_instance.standalone_db[0].address : null
}

output "db_instance_endpoint" {
  description = "The endpoint of the standalone RDS instance."
  value       = var.is_standalone_deployment ? aws_db_instance.standalone_db[0].endpoint : null
}

output "aurora_cluster_id" {
  description = "The ID of the Aurora cluster."
  value       = !var.is_standalone_deployment ? aws_rds_cluster.aurora_db[0].id : null
}

output "aurora_cluster_endpoint" {
  description = "The endpoint of the Aurora cluster (for writer)."
  value       = !var.is_standalone_deployment ? aws_rds_cluster.aurora_db[0].endpoint : null
}

output "aurora_cluster_reader_endpoint" {
  description = "The reader endpoint of the Aurora cluster."
  value       = !var.is_standalone_deployment ? aws_rds_cluster.aurora_db[0].reader_endpoint : null
}

output "security_group_id" {
  description = "The ID of the RDS security group."
  value       = aws_security_group.this.id
}

output "db_subnet_group_name_output" {
  description = "The name of the DB subnet group used."
  value       = aws_db_subnet_group.this.name
}
