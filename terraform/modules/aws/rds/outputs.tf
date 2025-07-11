output "rds_security_group_id" {
  description = "ID of the RDS Security Group"
  value       = aws_security_group.rds_sg.id
}

output "rds_cluster_endpoint" {
  value       = aws_rds_cluster.aurora.endpoint
  description = "RDS cluster writer endpoint"
}

output "rds_cluster_reader_endpoint" {
  value       = aws_rds_cluster.aurora.reader_endpoint
  description = "RDS cluster reader endpoint"
}
