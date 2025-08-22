# Hyperswitch Internal ALB Security Group (VPC Origin)
resource "aws_security_group" "hyperswitch_alb_sg" {
  name                   = "${var.stack_name}-hyperswitch-alb-sg"
  description            = "Security group for Hyperswitch internal ALB with VPC origin access"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-hyperswitch-alb-sg"
  })
}

# Note: No ingress rules needed for CloudFront VPC origin access
# CloudFront connects via service-managed ENI using AWS internal routing
# Only application-specific traffic rules should be added as needed
