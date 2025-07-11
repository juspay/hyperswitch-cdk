# Internal Load Balancer Security Group
resource "aws_security_group" "internal_alb_sg" {
  name                   = "${var.stack_name}-internal-alb-sg"
  description            = "Security group for internal load balancer"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-internal-alb-sg"
  })
}

# Internal LB -> EKS (Istio Gateway - egress)
resource "aws_vpc_security_group_egress_rule" "internal_alb_to_eks_egress" {
  security_group_id            = aws_security_group.internal_alb_sg.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow traffic to EKS cluster"
}

# Internal LB -> EKS (Istio Gateway - ingress)
resource "aws_vpc_security_group_ingress_rule" "eks_from_internal_alb_ingress" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.internal_alb_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow traffic from Internal LB"
}

# Internal LB -> EKS (Istio Gateway - health check - egress)
resource "aws_vpc_security_group_egress_rule" "internal_alb_to_eks_health_egress" {
  security_group_id            = aws_security_group.internal_alb_sg.id
  referenced_security_group_id = var.eks_cluster_security_group_id
  from_port                    = 15021
  to_port                      = 15021
  ip_protocol                  = "tcp"
  description                  = "Allow Istio health checks"
}

resource "aws_vpc_security_group_ingress_rule" "eks_from_internal_alb_health_ingress" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.internal_alb_sg.id
  from_port                    = 15021
  to_port                      = 15021
  ip_protocol                  = "tcp"
  description                  = "Allow Istio health checks from Internal LB"
}

resource "aws_security_group" "grafana_ingress_lb_sg" {
  name                   = "${var.stack_name}-grafana-ingress-lb"
  description            = "Security group for Grafana ingress load balancer"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = {
    Name = "${var.stack_name}-grafana-ingress-lb"
  }
}

resource "aws_vpc_security_group_egress_rule" "grafana_lb_egress" {
  security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
  description       = "Allow all outbound traffic from Grafana LB SG"
}

resource "aws_vpc_security_group_ingress_rule" "grafana_ingress_lb_vpn_https" {
  for_each = { for ip in var.vpn_ips : ip => ip if ip != "0.0.0.0/0" }

  security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  cidr_ipv4         = each.value
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow port 443 from VPN IP ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "grafana_ingress_lb_vpn_http" {
  for_each = { for ip in var.vpn_ips : ip => ip if ip != "0.0.0.0/0" }

  security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  cidr_ipv4         = each.value
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "Allow port 80 from VPN IP ${each.value}"
}

resource "aws_vpc_security_group_ingress_rule" "eks_from_grafana_lb_3000" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  from_port                    = 3000
  to_port                      = 3000
  ip_protocol                  = "tcp"
  description                  = "Allow port 3000 from Grafana LB SG"
}

resource "aws_vpc_security_group_ingress_rule" "eks_from_grafana_lb_80" {
  security_group_id            = var.eks_cluster_security_group_id
  referenced_security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow port 80 from Grafana LB SG"
}
