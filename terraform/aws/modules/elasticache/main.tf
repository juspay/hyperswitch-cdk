# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "elasticache_subnet_group" {
  name       = "${var.stack_name}-elasticache-subnet-group"
  subnet_ids = var.subnet_ids["elasticache_zone"]

  description = "Hyperswitch Elasticache subnet group"

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-elasticache-subnet-group"
  })
}

# ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "main" {
  cluster_id           = "${var.stack_name}-elasticache"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379

  subnet_group_name  = aws_elasticache_subnet_group.elasticache_subnet_group.name
  security_group_ids = [aws_security_group.elasticache_sg.id]

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-elasticache-cluster"
  })
}
