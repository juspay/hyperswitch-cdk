output "elasticache_security_group_id" {
  description = "ID of the ElastiCache Security Group"
  value       = aws_security_group.elasticache_sg.id
}

output "elasticache_cluster_endpoint_address" {
  value       = aws_elasticache_cluster.main.cache_nodes[0].address
  description = "ElastiCache Redis cluster endpoint"
}
