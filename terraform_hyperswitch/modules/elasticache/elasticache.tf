resource "aws_security_group" "this" {
  name        = var.security_group_name
  description = "Security group for ElastiCache cluster ${var.cluster_name}"
  vpc_id      = var.vpc_id
  tags        = var.tags

  # Ingress rules will be added from where this module is called,
  # or you can define common ones here if applicable (e.g., from specific app SGs).
  # CDK adds ingress rules from app SGs after creating this SG.
}

resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.stack_prefix}-hs-subnet-group" # Matches CDK CfnSubnetGroup 'HSSubnetGroup'
  subnet_ids = var.subnet_ids
  tags       = var.tags
  description = "Hyperswitch ElastiCache subnet group" # From CDK
}

resource "aws_elasticache_cluster" "this" {
  cluster_id           = var.cluster_name
  engine               = var.engine
  node_type            = var.node_type
  num_cache_nodes      = var.num_cache_nodes
  port                 = var.port
  subnet_group_name    = aws_elasticache_subnet_group.this.name
  security_group_ids   = [aws_security_group.this.id]
  # parameter_group_name = "default.redis6.x" # Specify if not using default, CDK uses default

  tags = var.tags

  # Note: CDK uses CfnCacheCluster which might have slightly different defaults or properties
  # than aws_elasticache_cluster. Review against specific needs.
}
