# ==========================================================
#                          Subnets
# ==========================================================

# --->  Public Subnets Group  <---

# Public Subnet
resource "aws_subnet" "public" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                     = "${var.stack_name}-public-subnet-${count.index + 1}"
      "kubernetes.io/role/elb" = "1"
      "aws-cdk:subnet-name"    = "public-subnet-1"
      "aws-cdk:subnet-type"    = "Public"
    }
  )
}

# Management Zone Subnets (Public)
resource "aws_subnet" "management_zone" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 12)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-management-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "management-zone"
      "aws-cdk:subnet-type" = "Public"
    }
  )
}

# External Incoming Zone Subnets (Public)
resource "aws_subnet" "external_incoming_zone" {
  count                   = length(var.availability_zones)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index + 20)
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-external-incoming-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "external-incoming-zone"
      "aws-cdk:subnet-type" = "Public"
    }
  )
}

# --->  Private Subnets with Egress Group  <---

# Isolated Subnet (Private with Egress)
resource "aws_subnet" "isolated" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-isolated-subnet-${count.index + 1}"
      "aws-cdk:subnet-name" = "isolated-subnet-1"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Database Isolated Subnets
resource "aws_subnet" "database_isolated" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 4)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-database-isolated-subnet-${count.index + 1}"
      "aws-cdk:subnet-name" = "database-isolated-subnet-1"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# EKS Worker Nodes Subnets (Larger /22 CIDR)
resource "aws_subnet" "eks_worker_nodes" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 6, count.index + 48) # /22 subnet starting at offset 48 (non-conflicting)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                                      = "${var.stack_name}-eks-worker-nodes-${count.index + 1}"
      "aws-cdk:subnet-name"                     = "eks-worker-nodes-one-zone"
      "aws-cdk:subnet-type"                     = "Private"
      "kubernetes.io/role/internal-elb"         = "1"
      "kubernetes.io/cluster/${var.stack_name}" = "shared"
    }
  )
}

# Utils Zone Subnets
resource "aws_subnet" "utils_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 40)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-utils-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "utils-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Service Layer Zone Subnets
resource "aws_subnet" "service_layer_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 16)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-service-layer-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "service-layer-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Data Stack Zone Subnets
resource "aws_subnet" "data_stack_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 18)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-data-stack-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "data-stack-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Outgoing Proxy LB Zone Subnets
resource "aws_subnet" "outgoing_proxy_lb_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 24)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-outgoing-proxy-lb-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "outgoing-proxy-lb-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Outgoing Proxy Zone Subnets
resource "aws_subnet" "outgoing_proxy_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 26)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-outgoing-proxy-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "outgoing-proxy-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Incoming NPCI Zone Subnets
resource "aws_subnet" "incoming_npci_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 32)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-incoming-npci-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "incoming-npci-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# EKS Control Plane Zone Subnets
resource "aws_subnet" "eks_control_plane_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 34)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-eks-control-plane-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "eks-control-plane-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Incoming Web Envoy Zone Subnets
resource "aws_subnet" "incoming_web_envoy_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 36)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-incoming-web-envoy-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "incoming-web-envoy-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# Incoming Istio LB Transit Zone Subnets
resource "aws_subnet" "istio_lb_transit_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 38)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-istio-lb-transit-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "istio-lb-transit-zone"
      "aws-cdk:subnet-type" = "Private"
    }
  )
}

# --->  Private Isolated Subnets Group  <---

# Locker Database Zone Subnets (Isolated)
resource "aws_subnet" "locker_database_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 14)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-locker-database-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "locker-database-zone"
      "aws-cdk:subnet-type" = "Isolated"
    }
  )
}

# Database Zone Subnets (Isolated)
resource "aws_subnet" "database_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 22)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-database-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "database-zone"
      "aws-cdk:subnet-type" = "Isolated"
    }
  )
}

# Locker Server Zone Subnets (Isolated)
resource "aws_subnet" "locker_server_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 28)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-locker-server-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "locker-server-zone"
      "aws-cdk:subnet-type" = "Isolated"
    }
  )
}

# ElastiCache Zone Subnets (Isolated)
resource "aws_subnet" "elasticache_zone" {
  count             = length(var.availability_zones)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 30)
  availability_zone = var.availability_zones[count.index]

  tags = merge(
    var.common_tags,
    {
      Name                  = "${var.stack_name}-elasticache-zone-${count.index + 1}"
      "aws-cdk:subnet-name" = "elasticache-zone"
      "aws-cdk:subnet-type" = "Isolated"
    }
  )
}
