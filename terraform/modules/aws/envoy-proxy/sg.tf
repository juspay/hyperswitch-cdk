# Envoy Proxy Security Group
resource "aws_security_group" "envoy_sg" {
  name                   = "${var.stack_name}-envoy-sg"
  description            = "Security group for Envoy proxy instances"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-envoy-sg"
  })
}

# HTTPS to S3
resource "aws_vpc_security_group_egress_rule" "envoy_https_s3" {
  security_group_id = aws_security_group.envoy_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow HTTPS to S3"
}

# DNS UDP
resource "aws_vpc_security_group_egress_rule" "envoy_dns_udp" {
  security_group_id = aws_security_group.envoy_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "Allow DNS UDP"
}

# DNS TCP
resource "aws_vpc_security_group_egress_rule" "envoy_dns_tcp" {
  security_group_id = aws_security_group.envoy_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "Allow DNS TCP"
}

# External LB -> Envoy (egress)
resource "aws_vpc_security_group_egress_rule" "external_lb_to_envoy_egress" {
  security_group_id            = var.external_alb_security_group_id
  referenced_security_group_id = aws_security_group.envoy_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow traffic to Envoy proxy"
}

# External LB -> Envoy (ingress)
resource "aws_vpc_security_group_ingress_rule" "envoy_from_external_lb_ingress" {
  security_group_id            = aws_security_group.envoy_sg.id
  referenced_security_group_id = var.external_alb_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow traffic from External LB"
}

# Envoy -> Internal LB (egress)
resource "aws_vpc_security_group_egress_rule" "envoy_to_internal_lb_egress" {
  security_group_id            = aws_security_group.envoy_sg.id
  referenced_security_group_id = var.internal_alb_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow traffic to Internal LB"
}

# Envoy -> Internal LB (ingress)
resource "aws_vpc_security_group_ingress_rule" "internal_lb_from_envoy_ingress" {
  security_group_id            = var.internal_alb_security_group_id
  referenced_security_group_id = aws_security_group.envoy_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow traffic from Envoy"
}
