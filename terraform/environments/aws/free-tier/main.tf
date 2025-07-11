# ==========================================================
#                     Terraform Configuration
# ==========================================================
terraform {
  required_version = ">= 0.12"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ==========================================================
#                        Data Sources
# ==========================================================
# Data source to fetch available AZs in the current region
data "aws_availability_zones" "available" {
  state = "available"
}

# Data source for Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Data source for VPC (after creation)
data "aws_vpc" "main" {
  id = aws_vpc.main.id
}

# ==========================================================
#                          Locals
# ==========================================================
locals {
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)
}

# ==========================================================
#                      VPC Configuration
# ==========================================================
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.stack_name}-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.stack_name}-igw"
  }
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.stack_name}-public-subnet-${count.index + 1}"
    Type = "public"
  }
}

# Private Subnets for RDS
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = {
    Name = "${var.stack_name}-private-subnet-${count.index + 1}"
    Type = "private"
  }
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.stack_name}-public-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# NAT Gateway for Private Subnets (using single NAT for cost optimization)
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.stack_name}-nat-eip"
  }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id

  tags = {
    Name = "${var.stack_name}-nat"
  }

  depends_on = [aws_internet_gateway.main]
}

# Route Table for Private Subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }

  tags = {
    Name = "${var.stack_name}-private-rt"
  }
}

# Private Route Table Associations
resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ==========================================================
#                     Security Groups
# ==========================================================
# Application Load Balancer Security Group
resource "aws_security_group" "app_alb" {
  name        = "${var.stack_name}-app-alb-sg"
  description = "Security group for Application Load Balancer"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.stack_name}-app-alb-sg"
  }
}

# ALB Ingress Rules
resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.app_alb.id
  description       = "Allow HTTP traffic"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_control_center" {
  security_group_id = aws_security_group.app_alb.id
  description       = "Allow Control Center traffic"
  from_port         = 9000
  to_port           = 9000
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_sdk" {
  security_group_id = aws_security_group.app_alb.id
  description       = "Allow SDK traffic"
  from_port         = 9050
  to_port           = 9050
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "alb_demo" {
  security_group_id = aws_security_group.app_alb.id
  description       = "Allow Demo app traffic"
  from_port         = 5252
  to_port           = 5252
  ip_protocol       = "tcp"
  cidr_ipv4         = "0.0.0.0/0"
}

# ALB Egress Rule
resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.app_alb.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# EC2 Instance Security Group
resource "aws_security_group" "ec2" {
  name        = "${var.stack_name}-ec2-sg"
  description = "Security group for EC2 instance"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.stack_name}-ec2-sg"
  }
}

# EC2 Ingress Rules - From ALB
resource "aws_vpc_security_group_ingress_rule" "ec2_http_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "Allow HTTP from ALB"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "ec2_control_center_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "Allow Control Center from ALB"
  from_port                    = 9000
  to_port                      = 9000
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "ec2_sdk_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "Allow SDK from ALB"
  from_port                    = 9050
  to_port                      = 9050
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "ec2_demo_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  description                  = "Allow Demo from ALB"
  from_port                    = 5252
  to_port                      = 5252
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.app_alb.id
}

resource "aws_vpc_security_group_ingress_rule" "ec2_ssh" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow SSH from VPC"
  from_port         = 22
  to_port           = 22
  ip_protocol       = "tcp"
  cidr_ipv4         = aws_vpc.main.cidr_block
}

# EC2 Egress Rule
resource "aws_vpc_security_group_egress_rule" "ec2_all" {
  security_group_id = aws_security_group.ec2.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# RDS Security Group
resource "aws_security_group" "rds" {
  name        = "${var.stack_name}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.stack_name}-rds-sg"
  }
}

# RDS Ingress Rule
resource "aws_vpc_security_group_ingress_rule" "rds_postgres" {
  security_group_id            = aws_security_group.rds.id
  description                  = "PostgreSQL access from EC2"
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2.id
}

# RDS Egress Rule
resource "aws_vpc_security_group_egress_rule" "rds_all" {
  security_group_id = aws_security_group.rds.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ElastiCache Security Group
resource "aws_security_group" "redis" {
  name        = "${var.stack_name}-redis-sg"
  description = "Security group for ElastiCache Redis"
  vpc_id      = aws_vpc.main.id

  tags = {
    Name = "${var.stack_name}-redis-sg"
  }
}

# Redis Ingress Rule
resource "aws_vpc_security_group_ingress_rule" "redis_access" {
  security_group_id            = aws_security_group.redis.id
  description                  = "Redis access from EC2"
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  referenced_security_group_id = aws_security_group.ec2.id
}

# Redis Egress Rule
resource "aws_vpc_security_group_egress_rule" "redis_all" {
  security_group_id = aws_security_group.redis.id
  description       = "Allow all outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ==========================================================
#                         IAM Roles
# ==========================================================
# IAM Role for EC2
resource "aws_iam_role" "ec2" {
  name = "${var.stack_name}-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

resource "aws_iam_role_policy" "ssm_custom" {
  name = "${var.stack_name}-ssm-custom-policy"
  role = aws_iam_role.ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:UpdateInstanceInformation",
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ec2messages:AcknowledgeMessage",
          "ec2messages:DeleteMessage",
          "ec2messages:FailMessage",
          "ec2messages:GetEndpoint",
          "ec2messages:GetMessages",
          "ec2messages:SendReply"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${var.stack_name}-ec2-profile"
  role = aws_iam_role.ec2.name
}

# ==========================================================
#                      RDS Database
# ==========================================================
# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${var.stack_name}-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.stack_name}-db-subnet-group"
  }
}

# RDS Parameter Group
resource "aws_db_parameter_group" "postgres" {
  name   = "${var.stack_name}-postgres-params"
  family = "postgres15"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
  }

  parameter {
    name  = "log_statement"
    value = "all"
  }

  tags = {
    Name = "${var.stack_name}-postgres-params"
  }
}

# RDS Instance (Free Tier)
resource "aws_db_instance" "main" {
  identifier     = "${var.stack_name}-db"
  engine         = "postgres"
  engine_version = "15"

  # Free tier specifications
  instance_class    = "db.t3.micro"
  allocated_storage = 20
  storage_type      = "gp2"

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  parameter_group_name   = aws_db_parameter_group.postgres.name

  skip_final_snapshot = true
  deletion_protection = false

  backup_retention_period = 7
  backup_window           = "03:00-04:00"
  maintenance_window      = "sun:04:00-sun:05:00"

  enabled_cloudwatch_logs_exports = ["postgresql"]

  tags = {
    Name = "${var.stack_name}-db"
  }
}

# ==========================================================
#                    ElastiCache Redis
# ==========================================================
# ElastiCache Subnet Group
resource "aws_elasticache_subnet_group" "main" {
  name       = "${var.stack_name}-cache-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = {
    Name = "${var.stack_name}-cache-subnet-group"
  }
}

# ElastiCache Parameter Group
resource "aws_elasticache_parameter_group" "redis" {
  name   = "${var.stack_name}-redis-params"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = {
    Name = "${var.stack_name}-redis-params"
  }
}

# ElastiCache Redis Cluster (Free Tier)
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.stack_name}-redis"
  engine               = "redis"
  engine_version       = "7.0"
  node_type            = "cache.t3.micro" # Free tier eligible
  num_cache_nodes      = 1
  parameter_group_name = aws_elasticache_parameter_group.redis.name
  subnet_group_name    = aws_elasticache_subnet_group.main.name
  security_group_ids   = [aws_security_group.redis.id]
  port                 = 6379

  snapshot_retention_limit = 1
  snapshot_window          = "03:00-05:00"
  maintenance_window       = "sun:05:00-sun:07:00"

  tags = {
    Name = "${var.stack_name}-redis"
  }
}

# ==========================================================
#                    Load Balancer
# ==========================================================
# Application Load Balancer
resource "aws_lb" "app" {
  name               = "${var.stack_name}-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_alb.id]
  subnets            = aws_subnet.public[*].id

  tags = {
    Name = "${var.stack_name}-app-alb"
  }
}

# Target Groups with consistent naming
resource "aws_lb_target_group" "router" {
  name     = "${var.stack_name}-router-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    timeout             = 30
    interval            = 60
    path                = "/health"
    matcher             = "200-499"
  }

  tags = {
    Name = "${var.stack_name}-router-tg"
  }
}

resource "aws_lb_target_group" "control_center" {
  name     = "${var.stack_name}-control-center-tg"
  port     = 9000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    enabled  = true
    path     = "/"
    protocol = "HTTP"
    matcher  = "200"
  }

  tags = {
    Name = "${var.stack_name}-control-center-tg"
  }
}

resource "aws_lb_target_group" "sdk" {
  name     = "${var.stack_name}-sdk-tg"
  port     = 9050
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    enabled  = true
    path     = "/web/${var.sdk_version}/${var.sdk_sub_version}/HyperLoader.js"
    protocol = "HTTP"
    matcher  = "200"
  }

  tags = {
    Name = "${var.stack_name}-sdk-tg"
  }
}

resource "aws_lb_target_group" "demo" {
  name     = "${var.stack_name}-demo-tg"
  port     = 5252
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.main.id

  health_check {
    enabled  = true
    path     = "/"
    protocol = "HTTP"
    matcher  = "200"
  }

  tags = {
    Name = "${var.stack_name}-demo-tg"
  }
}

# Target Group Attachments
resource "aws_lb_target_group_attachment" "router" {
  target_group_arn = aws_lb_target_group.router.arn
  target_id        = aws_instance.backend.id
  port             = 8080
}

resource "aws_lb_target_group_attachment" "control_center" {
  target_group_arn = aws_lb_target_group.control_center.arn
  target_id        = aws_instance.backend.id
  port             = 9000
}

resource "aws_lb_target_group_attachment" "sdk" {
  target_group_arn = aws_lb_target_group.sdk.arn
  target_id        = aws_instance.sdk.id
  port             = 9050
}

resource "aws_lb_target_group_attachment" "demo" {
  target_group_arn = aws_lb_target_group.demo.arn
  target_id        = aws_instance.sdk.id
  port             = 5252
}

# ALB Listeners
resource "aws_lb_listener" "router" {
  load_balancer_arn = aws_lb.app.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.router.arn
  }
}

resource "aws_lb_listener" "control_center" {
  load_balancer_arn = aws_lb.app.arn
  port              = "9000"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.control_center.arn
  }
}

resource "aws_lb_listener" "sdk" {
  load_balancer_arn = aws_lb.app.arn
  port              = "9050"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sdk.arn
  }
}

resource "aws_lb_listener" "demo" {
  load_balancer_arn = aws_lb.app.arn
  port              = "5252"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.demo.arn
  }
}

# ==========================================================
#                CloudFront Distributions
# ==========================================================
resource "aws_cloudfront_distribution" "app" {
  enabled = true
  comment = "Hyperswitch App Free Tier Distribution"
  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "app-alb-80"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "app-alb-80"

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.stack_name}-app-distribution"
  }
}

resource "aws_cloudfront_distribution" "control_center" {
  enabled = true
  comment = "Hyperswitch Control Center Free Tier Distribution"
  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "app-alb-9000"

    custom_origin_config {
      http_port              = 9000
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "app-alb-9000"

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.stack_name}-control-center-distribution"
  }
}

resource "aws_cloudfront_distribution" "sdk" {
  enabled = true
  comment = "Hyperswitch SDK Free Tier Distribution"
  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "app-alb-9050"

    custom_origin_config {
      http_port              = 9050
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "app-alb-9050"

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.stack_name}-sdk-distribution"
  }
}

resource "aws_cloudfront_distribution" "demo" {
  enabled = true
  comment = "Hyperswitch Demo App Free Tier Distribution"
  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "app-alb-5252"

    custom_origin_config {
      http_port              = 5252
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "app-alb-5252"

    forwarded_values {
      query_string = true
      headers      = ["*"]

      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name = "${var.stack_name}-demo-distribution"
  }
}

# ==========================================================
#                      EC2 Instances
# ==========================================================
# Backend Instance (Router + Control Center)
resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = base64encode(templatefile("${path.module}/userdata/app-dashboard.sh", {
    redis_host             = aws_elasticache_cluster.redis.cache_nodes[0].address
    db_host                = aws_db_instance.main.address
    db_username            = var.db_username
    db_password            = var.db_password
    db_name                = var.db_name
    admin_api_key          = var.admin_api_key
    app_cloudfront_url     = aws_cloudfront_distribution.app.domain_name
    sdk_cloudfront_url     = aws_cloudfront_distribution.sdk.domain_name
    router_version         = var.router_version
    control_center_version = var.control_center_version
    sdk_version            = var.sdk_version
    sdk_sub_version        = var.sdk_sub_version
  }))

  tags = {
    Name = "${var.stack_name}-backend-instance"
    Type = "backend"
  }

  # Ensure RDS and ElastiCache are ready before starting EC2
  depends_on = [
    aws_db_instance.main,
    aws_elasticache_cluster.redis,
    aws_cloudfront_distribution.app,
    aws_cloudfront_distribution.sdk
  ]
}

# Frontend Instance (SDK + Demo App)
resource "aws_instance" "sdk" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.public[1].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = base64encode(templatefile("${path.module}/userdata/sdk.sh", {
    app_cloudfront_url  = aws_cloudfront_distribution.app.domain_name
    sdk_cloudfront_url  = aws_cloudfront_distribution.sdk.domain_name
    demo_cloudfront_url = aws_cloudfront_distribution.demo.domain_name
    admin_api_key       = var.admin_api_key
    sdk_version         = var.sdk_version
    sdk_sub_version     = var.sdk_sub_version
  }))

  tags = {
    Name = "${var.stack_name}-sdk-instance"
    Type = "sdk"
  }

  # Frontend depends CloudFront distributions
  depends_on = [
    aws_cloudfront_distribution.app,
    aws_cloudfront_distribution.sdk
  ]
}
