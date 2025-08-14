locals {
  name_prefix = "${var.stack_name}-external-jump"
}

# Data source for AMI
data "aws_ami" "amazon_linux_2" {
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

# Security Group for External Jump Host
resource "aws_security_group" "external_jump" {
  name        = "${local.name_prefix}-sg"
  description = "Security group for external jump host"
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

# Allow SSH from same security group (for Session Manager)
resource "aws_vpc_security_group_ingress_rule" "self_ssh" {
  security_group_id            = aws_security_group.external_jump.id
  referenced_security_group_id = aws_security_group.external_jump.id
  from_port                    = 37689
  to_port                      = 37689
  ip_protocol                  = "tcp"
  description                  = "Allow SSH from same security group"
}

# Allow HTTPS to VPC endpoints
resource "aws_vpc_security_group_egress_rule" "https_to_vpce" {
  count = var.vpce_security_group_id != null ? 1 : 0

  security_group_id            = aws_security_group.external_jump.id
  referenced_security_group_id = var.vpce_security_group_id
  from_port                    = 443
  to_port                      = 443
  ip_protocol                  = "tcp"
  description                  = "Allow HTTPS to VPC endpoints"
}

# IAM Role for External Jump Host
resource "aws_iam_role" "external_jump" {
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

# IAM Policy for Session Manager
resource "aws_iam_policy" "session_manager" {
  name        = "${local.name_prefix}-session-manager-policy"
  description = "Policy for Session Manager access"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssmmessages:CreateControlChannel",
          "ssmmessages:CreateDataChannel",
          "ssmmessages:OpenControlChannel",
          "ssmmessages:OpenDataChannel",
          "ssm:UpdateInstanceInformation"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetEncryptionConfiguration"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt"
        ]
        Resource = var.kms_key_arn
      },
      {
        Effect = "Allow"
        Action = [
          "kms:GenerateDataKey"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.common_tags
}

# Attach Session Manager policy to role
resource "aws_iam_role_policy_attachment" "session_manager" {
  count = var.enable_ssm_session_manager ? 1 : 0

  role       = aws_iam_role.external_jump.name
  policy_arn = aws_iam_policy.session_manager.arn
}

# Attach AWS managed policies
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.external_jump.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  count = var.enable_ssm_session_manager ? 1 : 0

  role       = aws_iam_role.external_jump.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ssm_full_access" {
  count = var.enable_ssm_full_access ? 1 : 0

  role       = aws_iam_role.external_jump.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMFullAccess"
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "external_jump" {
  name = "${local.name_prefix}-profile"
  role = aws_iam_role.external_jump.name

  tags = var.common_tags
}

# EC2 Instance
resource "aws_instance" "external_jump" {
  ami           = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux_2[0].id
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.external_jump.id]
  iam_instance_profile   = aws_iam_instance_profile.external_jump.name

  associate_public_ip_address = true

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
