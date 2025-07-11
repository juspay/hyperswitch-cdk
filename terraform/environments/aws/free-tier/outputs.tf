# VPC Outputs
output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# RDS Outputs
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
}

output "rds_address" {
  description = "RDS instance address"
  value       = aws_db_instance.main.address
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.main.db_name
}

# ElastiCache Outputs
output "redis_endpoint" {
  description = "Redis cluster endpoint"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.redis.port
}

# EC2 Outputs
output "backend_instance_id" {
  description = "ID of the backend EC2 instance"
  value       = aws_instance.backend.id
}

output "backend_instance_public_ip" {
  description = "Public IP of the backend EC2 instance"
  value       = aws_instance.backend.public_ip
}

output "frontend_instance_id" {
  description = "ID of the frontend EC2 instance"
  value       = aws_instance.sdk.id
}

output "frontend_instance_public_ip" {
  description = "Public IP of the frontend EC2 instance"
  value       = aws_instance.sdk.public_ip
}


# Application URLs
output "api_url" {
  description = "URL for the Hyperswitch API"
  value       = "https://${aws_cloudfront_distribution.app.domain_name}"
}

output "api_health_url" {
  description = "URL for the Hyperswitch API health check"
  value       = "https://${aws_cloudfront_distribution.app.domain_name}/health"
}

output "control_center_url" {
  description = "URL for the Control Center"
  value       = "https://${aws_cloudfront_distribution.control_center.domain_name}"
}

output "sdk_url" {
  description = "URL for the SDK"
  value       = "https://${aws_cloudfront_distribution.sdk.domain_name}"
}

output "sdk_loader_url" {
  description = "URL for the SDK loader script"
  value       = "https://${aws_cloudfront_distribution.sdk.domain_name}/HyperLoader.js"
}

output "demo_app_url" {
  description = "URL for the demo application"
  value       = "https://${aws_cloudfront_distribution.demo.domain_name}"
}

# Direct ALB URLs (for testing)
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.app.dns_name
}

output "alb_api_url" {
  description = "Direct ALB URL for API (for testing)"
  value       = "http://${aws_lb.app.dns_name}"
}

output "alb_control_center_url" {
  description = "Direct ALB URL for Control Center (for testing)"
  value       = "http://${aws_lb.app.dns_name}:9000"
}

output "alb_sdk_url" {
  description = "Direct ALB URL for SDK (for testing)"
  value       = "http://${aws_lb.app.dns_name}:9050"
}

output "alb_demo_url" {
  description = "Direct ALB URL for Demo App (for testing)"
  value       = "http://${aws_lb.app.dns_name}:5252"
}

# Security Group IDs
output "ec2_security_group_id" {
  description = "Security group ID for EC2 instance"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "Security group ID for RDS"
  value       = aws_security_group.rds.id
}

output "redis_security_group_id" {
  description = "Security group ID for Redis"
  value       = aws_security_group.redis.id
}
