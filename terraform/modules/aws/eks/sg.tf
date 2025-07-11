# ==========================================================
#              EKS Cluster Security Group Rules
# ==========================================================


# resource "aws_vpc_security_group_egress_rule" "eks_block_all_egress" {
#   security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
#   cidr_ipv4         = ""
#   from_port         = 0
#   to_port           = 0
#   ip_protocol       = "-1"
#   description       = "Block all egress traffic from EKS cluster nodes and pods"
# }

# ==========================================================
#              RDS and Elasticache Connections
# ==========================================================

resource "aws_vpc_security_group_ingress_rule" "rds_ingress_from_eks" {
  security_group_id            = var.rds_security_group_id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 5432 # PostgreSQL port
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow EKS cluster nodes and pods to connect to RDS PostgreSQL"
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_ingress_from_eks" {
  security_group_id            = var.elasticache_security_group_id
  referenced_security_group_id = aws_eks_cluster.main.vpc_config[0].cluster_security_group_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Allow Redis access from EKS cluster"
}

