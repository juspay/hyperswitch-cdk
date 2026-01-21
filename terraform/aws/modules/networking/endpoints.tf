# ==========================================================
#                      VPC Endpoints
# ==========================================================

# AWS Region
data "aws_region" "current" {}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.${data.aws_region.current.name}.s3"

  route_table_ids = concat(
    [aws_route_table.isolated.id],
    aws_route_table.private_with_nat[*].id
  )

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-s3-endpoint"
    }
  )
}

# VPC Endpoint for SSM
resource "aws_vpc_endpoint" "ssm" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ssm"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.incoming_web_envoy_zone[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ssm-endpoint"
  }
}

# VPC Endpoint for SSM Messages
resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ssmmessages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.incoming_web_envoy_zone[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ssmmessages-endpoint"
  }
}

# VPC Endpoint for EC2 Messages
resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ec2messages"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.incoming_web_envoy_zone[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ec2messages-endpoint"
  }
}

# VPC Endpoint for Secrets Manager
resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.locker_database_zone[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-secretsmanager-endpoint"
  }
}

# VPC Endpoint for KMS
resource "aws_vpc_endpoint" "kms" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.kms"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.database_zone[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-kms-endpoint"
  }
}

# VPC Endpoint for RDS
resource "aws_vpc_endpoint" "rds" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.rds"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.database_zone[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-rds-endpoint"
  }
}

# ==========================================================
#              EKS Required VPC Endpoints
# ==========================================================

# VPC Endpoint for EKS API
resource "aws_vpc_endpoint" "eks" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.eks"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.eks_control_plane_zone[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-eks-endpoint"
  }
}

# VPC Endpoint for ECR API (required for container image pulls)
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.api"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.eks_worker_nodes[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ecr-api-endpoint"
  }
}

# VPC Endpoint for ECR Docker Registry (required for container image pulls)
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ecr.dkr"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.eks_worker_nodes[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ecr-dkr-endpoint"
  }
}

# VPC Endpoint for STS (required for IRSA - IAM Roles for Service Accounts)
resource "aws_vpc_endpoint" "sts" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.sts"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.eks_worker_nodes[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-sts-endpoint"
  }
}

# VPC Endpoint for EC2 (required for EKS node registration and metadata)
resource "aws_vpc_endpoint" "ec2" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.ec2"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.eks_worker_nodes[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-ec2-endpoint"
  }
}

# VPC Endpoint for CloudWatch Logs (required for EKS logging)
resource "aws_vpc_endpoint" "logs" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.logs"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.eks_worker_nodes[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-logs-endpoint"
  }
}

# VPC Endpoint for Elastic Load Balancing (required for ALB/NLB controllers)
resource "aws_vpc_endpoint" "elasticloadbalancing" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.elasticloadbalancing"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.istio_lb_transit_zone[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-elb-endpoint"
  }
}

# ==========================================================
#              Monitoring and Autoscaling VPC Endpoints
# ==========================================================

# VPC Endpoint for CloudWatch Monitoring (required for metrics collection)
resource "aws_vpc_endpoint" "monitoring" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.monitoring"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.eks_worker_nodes[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-monitoring-endpoint"
  }
}

# VPC Endpoint for Auto Scaling (required for Cluster Autoscaler)
resource "aws_vpc_endpoint" "autoscaling" {
  vpc_id             = aws_vpc.main.id
  service_name       = "com.amazonaws.${data.aws_region.current.name}.autoscaling"
  vpc_endpoint_type  = "Interface"
  subnet_ids         = aws_subnet.eks_worker_nodes[*].id
  security_group_ids = [aws_security_group.vpc_endpoints.id]

  private_dns_enabled = true

  tags = {
    Name = "${var.stack_name}-autoscaling-endpoint"
  }
}
