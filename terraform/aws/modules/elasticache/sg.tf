# Security Group for ElastiCache
resource "aws_security_group" "elasticache_sg" {
  name                   = "${var.stack_name}-elasticache-SG"
  description            = "Security group for Hyperswitch ElastiCache"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-elasticache-SG"
  })
}
