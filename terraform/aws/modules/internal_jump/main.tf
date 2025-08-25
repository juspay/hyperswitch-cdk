locals {
  name_prefix = "${var.stack_name}-internal-jump"
}

# Data source for AMI
data "aws_ami" "amazon_linux" {
  count = var.ami_id == null ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Security Group for Internal Jump Host
resource "aws_security_group" "internal_jump" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for internal jump host"
  vpc_id      = var.vpc_id

  # Explicitly deny all outbound traffic by default (matching CDK allowOutboundTraffic: false)
  egress = []

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-sg"
    }
  )
}

# Allow SSH from external jump host
resource "aws_vpc_security_group_ingress_rule" "ssh_from_external_jump" {
  security_group_id            = aws_security_group.internal_jump.id
  referenced_security_group_id = var.external_jump_sg_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "Allow SSH from external jump host"
}

# Egress rules for database access
resource "aws_vpc_security_group_egress_rule" "egress_to_rds" {
  count = var.rds_sg_id != null ? 1 : 0

  security_group_id            = aws_security_group.internal_jump.id
  referenced_security_group_id = var.rds_sg_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow PostgreSQL access to RDS"
}

resource "aws_vpc_security_group_egress_rule" "egress_to_elasticache" {
  count = var.elasticache_sg_id != null ? 1 : 0

  security_group_id            = aws_security_group.internal_jump.id
  referenced_security_group_id = var.elasticache_sg_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Allow Redis access to ElastiCache"
}

resource "aws_vpc_security_group_egress_rule" "egress_to_locker_db" {
  count = var.locker_db_sg_id != null ? 1 : 0

  security_group_id            = aws_security_group.internal_jump.id
  referenced_security_group_id = var.locker_db_sg_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow PostgreSQL access to locker database"
}

resource "aws_vpc_security_group_egress_rule" "egress_to_locker_ec2" {
  count = var.locker_ec2_sg_id != null ? 1 : 0

  security_group_id            = aws_security_group.internal_jump.id
  referenced_security_group_id = var.locker_ec2_sg_id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "Allow SSH access to locker EC2"
}

# Ingress rules from internal jump to other services
resource "aws_vpc_security_group_ingress_rule" "rds_from_internal_jump" {
  count = var.rds_sg_id != null ? 1 : 0

  security_group_id            = var.rds_sg_id
  referenced_security_group_id = aws_security_group.internal_jump.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow internal jump host to access RDS"
}

resource "aws_vpc_security_group_ingress_rule" "elasticache_from_internal_jump" {
  count = var.elasticache_sg_id != null ? 1 : 0

  security_group_id            = var.elasticache_sg_id
  referenced_security_group_id = aws_security_group.internal_jump.id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"
  description                  = "Allow internal jump host to access ElastiCache"
}

resource "aws_vpc_security_group_ingress_rule" "locker_ec2_from_internal_jump" {
  count = var.locker_ec2_sg_id != null ? 1 : 0

  security_group_id            = var.locker_ec2_sg_id
  referenced_security_group_id = aws_security_group.internal_jump.id
  from_port                    = 22
  to_port                      = 22
  ip_protocol                  = "tcp"
  description                  = "Allow internal jump host to SSH to locker EC2"
}

resource "aws_vpc_security_group_ingress_rule" "locker_db_from_internal_jump" {
  count = var.locker_db_sg_id != null ? 1 : 0

  security_group_id            = var.locker_db_sg_id
  referenced_security_group_id = aws_security_group.internal_jump.id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "Allow internal jump host to access locker database"
}

# IAM Role for Internal Jump Host
resource "aws_iam_role" "internal_jump" {
  name = "${local.name_prefix}-role"

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

  tags = var.common_tags
}

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.internal_jump.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "internal_jump" {
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.internal_jump.name

  tags = var.common_tags
}

# EC2 Instance
resource "aws_instance" "internal_jump" {
  ami           = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux[0].id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.internal_jump.id]
  iam_instance_profile   = aws_iam_instance_profile.internal_jump.name

  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = 20
    encrypted   = true
  }

  tags = merge(
    var.common_tags,
    {
      Name = "${local.name_prefix}-instance"
    }
  )

  lifecycle {
    ignore_changes = [ami]
  }
}
