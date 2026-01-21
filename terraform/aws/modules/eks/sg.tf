# ==========================================================
#                   EKS Master Security Group
# ==========================================================

# Additional security group for EKS cluster with strict rules
resource "aws_security_group" "eks_master_sg" {
  name                   = "${var.stack_name}-eks-master-sg"
  description            = "Additional security group for EKS cluster control plane"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-eks-master-sg"
    Purpose = "EKS cluster control plane additional security group"
  })
}

# ==========================================================
#              EKS Node Group Security Group
# ==========================================================

# Security group for EKS worker nodes with internet proxy enforcement
resource "aws_security_group" "eks_nodegroup_sg" {
  name                   = "${var.stack_name}-eks-nodegroup-sg"
  description            = "Security group for EKS worker nodes with internet proxy enforcement"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-eks-nodegroup-sg"
    Purpose = "Enforce proxy usage for internet HTTP traffic"
  })
}

# ==========================================================
#              Node to Node Communication
# ==========================================================

# Allow all traffic between nodes (same security group)
resource "aws_vpc_security_group_ingress_rule" "node_to_node_all" {
  security_group_id            = aws_security_group.eks_nodegroup_sg.id
  referenced_security_group_id = aws_security_group.eks_nodegroup_sg.id
  ip_protocol                  = "-1"
  description                  = "Allow all traffic between EKS nodes"
}

resource "aws_vpc_security_group_egress_rule" "node_to_node_all" {
  security_group_id            = aws_security_group.eks_nodegroup_sg.id
  referenced_security_group_id = aws_security_group.eks_nodegroup_sg.id
  ip_protocol                  = "-1"
  description                  = "Allow all traffic between EKS nodes"
}

# ==========================================================
#              Node to Control Plane Communication
# ==========================================================

# Allow all traffic from nodes to master security group
resource "aws_vpc_security_group_egress_rule" "node_to_master_all" {
  security_group_id            = aws_security_group.eks_nodegroup_sg.id
  referenced_security_group_id = aws_security_group.eks_master_sg.id
  ip_protocol                  = "-1"
  description                  = "Allow all traffic from nodes to EKS master security group"
}

# Allow all traffic from master to nodes (ingress on node group SG)
resource "aws_vpc_security_group_ingress_rule" "node_from_master_all" {
  security_group_id            = aws_security_group.eks_nodegroup_sg.id
  referenced_security_group_id = aws_security_group.eks_master_sg.id
  ip_protocol                  = "-1"
  description                  = "Allow all traffic from EKS master security group to nodes"
}

# Allow all traffic from nodes to master (ingress on master SG)
resource "aws_vpc_security_group_ingress_rule" "master_from_node_all" {
  security_group_id            = aws_security_group.eks_master_sg.id
  referenced_security_group_id = aws_security_group.eks_nodegroup_sg.id
  ip_protocol                  = "-1"
  description                  = "Allow all traffic from EKS node group to master security group"
}

# Allow all traffic from master to nodes (egress on master SG)
resource "aws_vpc_security_group_egress_rule" "master_to_node_all" {
  security_group_id            = aws_security_group.eks_master_sg.id
  referenced_security_group_id = aws_security_group.eks_nodegroup_sg.id
  ip_protocol                  = "-1"
  description                  = "Allow all traffic from EKS master security group to nodes"
}

# Allow master SG to access VPC endpoints for AWS services
resource "aws_vpc_security_group_egress_rule" "master_to_vpc_endpoints_https" {
  security_group_id            = aws_security_group.eks_master_sg.id
  referenced_security_group_id = var.vpc_endpoints_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS traffic from EKS master to VPC endpoints"
}

# Allow master SG to access internal VPC services
resource "aws_vpc_security_group_egress_rule" "master_vpc_internal" {
  security_group_id = aws_security_group.eks_master_sg.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
  description       = "Allow EKS master to access internal VPC services"
}

# ==========================================================
#       VPC Internal Traffic (RDS, ElastiCache, etc.)
# ==========================================================

# Allow all traffic within VPC for internal services
resource "aws_vpc_security_group_egress_rule" "node_vpc_internal" {
  security_group_id = aws_security_group.eks_nodegroup_sg.id
  cidr_ipv4         = var.vpc_cidr
  ip_protocol       = "-1"
  description       = "Allow all traffic within VPC for internal services (RDS, ElastiCache, etc.)"
}

# ==========================================================
#                      DNS Resolution
# ==========================================================

# Allow DNS resolution within VPC only (using VPC resolver)
resource "aws_vpc_security_group_egress_rule" "node_dns_udp" {
  security_group_id = aws_security_group.eks_nodegroup_sg.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
  description       = "Allow DNS resolution (UDP) within VPC"
}

resource "aws_vpc_security_group_egress_rule" "node_dns_tcp" {
  security_group_id = aws_security_group.eks_nodegroup_sg.id
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
  description       = "Allow DNS resolution (TCP) within VPC"
}

# ==========================================================
#              RDS and ElastiCache Ingress Rules
# ==========================================================

# Allow EKS master security group to access RDS
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_master" {
  security_group_id            = var.rds_security_group_id
  referenced_security_group_id = aws_security_group.eks_master_sg.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow PostgreSQL access from EKS master security group"
}

# Allow EKS node groups to access RDS
resource "aws_vpc_security_group_ingress_rule" "rds_from_eks_nodegroup" {
  security_group_id            = var.rds_security_group_id
  referenced_security_group_id = aws_security_group.eks_nodegroup_sg.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow PostgreSQL access from EKS node groups"
}

# Allow EKS master security group to access ElastiCache
resource "aws_vpc_security_group_ingress_rule" "elasticache_from_eks_master" {
  security_group_id            = var.elasticache_security_group_id
  referenced_security_group_id = aws_security_group.eks_master_sg.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Allow Redis access from EKS master security group"
}

# Allow EKS node groups to access ElastiCache
resource "aws_vpc_security_group_ingress_rule" "elasticache_from_eks_nodegroup" {
  security_group_id            = var.elasticache_security_group_id
  referenced_security_group_id = aws_security_group.eks_nodegroup_sg.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Allow Redis access from EKS node groups"
}

# ==========================================================
#              VPC Endpoints Access for ECR/AWS Services
# ==========================================================

# Allow HTTPS traffic to VPC endpoints for ECR, EKS API, etc.
resource "aws_vpc_security_group_egress_rule" "node_to_vpc_endpoints_https" {
  security_group_id            = aws_security_group.eks_nodegroup_sg.id
  referenced_security_group_id = var.vpc_endpoints_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS traffic to VPC endpoints (ECR, EKS API, etc.)"
}

# Allow HTTP traffic to VPC endpoints (some services use HTTP)
resource "aws_vpc_security_group_egress_rule" "node_to_vpc_endpoints_http" {
  security_group_id            = aws_security_group.eks_nodegroup_sg.id
  referenced_security_group_id = var.vpc_endpoints_security_group_id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
  description                  = "Allow HTTP traffic to VPC endpoints"
}

# ==========================================================
#              S3 Gateway Endpoint Access
# ==========================================================

# Allow HTTPS traffic to S3 gateway endpoint (uses AWS prefix list, not VPC CIDR)
resource "aws_vpc_security_group_egress_rule" "node_to_s3_gateway" {
  security_group_id = aws_security_group.eks_nodegroup_sg.id
  prefix_list_id    = var.s3_vpc_endpoint_prefix_list_id
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "Allow HTTPS traffic to S3 gateway endpoint"
}

