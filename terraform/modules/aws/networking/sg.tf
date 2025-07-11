# Security Group for VPC Endpoints
resource "aws_security_group" "vpc_endpoints" {
  name_prefix            = "${var.stack_name}-vpce-"
  vpc_id                 = aws_vpc.main.id
  description            = "Security group for VPC Endpoints"
  revoke_rules_on_delete = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-vpce-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "vpc_endpoints_ingress" {
  security_group_id = aws_security_group.vpc_endpoints.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow https traffic to VPC Endpoints"
}

resource "aws_vpc_security_group_egress_rule" "vpc_endpoints_egress" {
  security_group_id = aws_security_group.vpc_endpoints.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from VPC Endpoints"
}
