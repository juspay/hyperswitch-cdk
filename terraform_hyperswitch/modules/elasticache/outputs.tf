output "cluster_id" {
  description = "The ID of the ElastiCache cluster."
  value       = aws_elasticache_cluster.this.id
}

output "cluster_address" {
  description = "The DNS address of the ElastiCache cluster's primary endpoint."
  value       = aws_elasticache_cluster.this.cache_nodes[0].address # For single node cluster
}

output "cluster_port" {
  description = "The port of the ElastiCache cluster's primary endpoint."
  value       = aws_elasticache_cluster.this.cache_nodes[0].port # For single node cluster
}

output "security_group_id" {
  description = "The ID of the ElastiCache security group."
  value       = aws_security_group.this.id
}
