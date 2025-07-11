# Squid Internal Load Balancer Security Group
resource "aws_security_group" "squid_internal_lb_sg" {
  name                   = "${var.stack_name}-squid-internal-lb-sg"
  description            = "Security group for Squid internal ALB"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  # # This means: no default egress, only what you define separately.
  # egress = []

  tags = {
    Name = "${var.stack_name}-squid-internal-lb-sg"
  }
}

# Allow EKS cluster to connect to Squid ALB
resource "aws_vpc_security_group_egress_rule" "eks_to_squid_lb" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.squid_internal_lb_sg.id
  from_port                    = 3128
  to_port                      = 3128
  ip_protocol                  = "tcp"
  description                  = "Allow outbound traffic to Squid proxy"
}

resource "aws_vpc_security_group_ingress_rule" "squid_lb_from_eks" {
  security_group_id            = aws_security_group.squid_internal_lb_sg.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  from_port                    = 3128
  to_port                      = 3128
  ip_protocol                  = "tcp"
  description                  = "Allow traffic from EKS cluster security group"
}

# Squid ASG Security Group
resource "aws_security_group" "squid_asg_sg" {
  name                   = "${var.stack_name}-squid-asg-sg"
  description            = "Security group for Squid Auto Scaling Group instances"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = {
    Name = "${var.stack_name}-squid-asg-sg"
  }
}

# Squid Internal LB -> Squid ASG
resource "aws_vpc_security_group_egress_rule" "squid_lb_to_asg" {
  security_group_id            = aws_security_group.squid_internal_lb_sg.id
  referenced_security_group_id = aws_security_group.squid_asg_sg.id
  from_port                    = 3128
  to_port                      = 3128
  ip_protocol                  = "tcp"
  description                  = "Allow traffic to Squid ASG instances"
}

resource "aws_vpc_security_group_ingress_rule" "squid_asg_from_lb" {
  security_group_id            = aws_security_group.squid_asg_sg.id
  referenced_security_group_id = aws_security_group.squid_internal_lb_sg.id
  from_port                    = 3128
  to_port                      = 3128
  ip_protocol                  = "tcp"
  description                  = "Allow traffic from Squid Internal LB"
}

# Squid ASG -> Internet
resource "aws_vpc_security_group_egress_rule" "squid_asg_to_http" {
  security_group_id = aws_security_group.squid_asg_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow HTTP to internet"
}

resource "aws_vpc_security_group_egress_rule" "squid_asg_to_https" {
  security_group_id = aws_security_group.squid_asg_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow HTTPS to internet"
}
