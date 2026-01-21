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

# CloudFront IP ranges data source
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

# CloudFront -> Hyperswitch ALB (HTTP)
resource "aws_vpc_security_group_ingress_rule" "hyperswitch_alb_from_cloudfront" {
  security_group_id = aws_security_group.hyperswitch_alb_sg.id
  prefix_list_id    = data.aws_ec2_managed_prefix_list.cloudfront.id
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow HTTP traffic from CloudFront"
}
