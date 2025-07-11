# Data sources
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Envoy Proxy Infrastructure
locals {
  envoy_config_content = replace(
    replace(
      replace(
        file("${path.module}/configurations/envoy/envoy.yaml"),
        "{{external_loadbalancer_dns}}", var.external_alb_distribution_domain_name
      ),
      "{{internal_loadbalancer_dns}}", var.internal_alb_domain_name
    ),
    "{{eks_cluster_name}}", "${var.stack_name}-cluster"
  )

  envoy_userdata_content = replace(
    file("${path.module}/userdata/envoy_userdata.sh"),
    "{{bucket-name}}", var.proxy_config_bucket_name
  )
}

# S3 Object for Envoy Configuration
resource "aws_s3_object" "envoy_config" {
  bucket  = var.proxy_config_bucket_name
  key     = "envoy/envoy.yaml"
  content = local.envoy_config_content
  
  # This ensures the object is recreated when the content changes
  etag = md5(local.envoy_config_content)
}

# IAM Role for Envoy Instances
resource "aws_iam_role" "envoy_instance_role" {
  name = "${var.stack_name}-envoy-instance-role"

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

  tags = merge(
    var.common_tags,
    {
      Name = "${var.stack_name}-envoy-instance-role"
    }
  )
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "envoy_ssm_policy" {
  role       = aws_iam_role.envoy_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom policy for S3 access
resource "aws_iam_role_policy" "envoy_s3_policy" {
  name = "${var.stack_name}-envoy-s3-policy"
  role = aws_iam_role.envoy_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          var.proxy_config_bucket_arn,
          "${var.proxy_config_bucket_arn}/*"
        ]
      }
    ]
  })
}

# Custom policy for SSM parameters
resource "aws_iam_role_policy" "envoy_ssm_parameters_policy" {
  name = "${var.stack_name}-envoy-ssm-parameters-policy"
  role = aws_iam_role.envoy_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "*"
      }
    ]
  })
}

# IAM Instance Profile
resource "aws_iam_instance_profile" "envoy_instance_profile" {
  name = "${var.stack_name}-envoy-instance-profile"
  role = aws_iam_role.envoy_instance_role.name
}

# Generate an RSA key pair locally
resource "tls_private_key" "envoy" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key Pair for Envoy instances
resource "aws_key_pair" "envoy_key_pair" {
  key_name   = "${var.stack_name}-envoy-proxy-keypair-${data.aws_region.current.name}"
  public_key = tls_private_key.envoy.public_key_openssh
}

# save the private key to a local file
resource "local_file" "envoy_private_key" {
  filename        = "${path.module}/envoy_public_key.pem"
  content         = tls_private_key.envoy.private_key_pem
  file_permission = "0600"
}

# Launch Template for Envoy instances
resource "aws_launch_template" "envoy_launch_template" {
  name_prefix   = "${var.stack_name}-envoy-launch-template-"
  image_id      = var.envoy_image_ami
  instance_type = "t3.medium"
  key_name      = aws_key_pair.envoy_key_pair.key_name

  vpc_security_group_ids = [aws_security_group.envoy_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.envoy_instance_profile.name
  }

  user_data = base64encode(local.envoy_userdata_content)

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${var.stack_name}-envoy-proxy-instance"
    })
  }
  
  # Force new version when config changes
  description = "Config hash: ${substr(md5(local.envoy_config_content), 0, 8)}"
}

# Auto Scaling Group
resource "aws_autoscaling_group" "envoy_asg" {
  name                = "${var.stack_name}-envoy-asg"
  vpc_zone_identifier = var.subnet_ids["incoming_web_envoy_zone"]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.envoy_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [var.envoy_target_group_arn]
  health_check_type = "ELB"
  
  # Instance refresh configuration to replace instances when config changes
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 60
    }
    triggers = ["tag"]
  }

  depends_on = [aws_s3_object.envoy_config]

  tag {
    key                 = "Name"
    value               = "${var.stack_name}-envoy-asg"
    propagate_at_launch = true
  }
  
  # Tag that changes when configuration changes to trigger instance refresh
  tag {
    key                 = "ConfigVersion"
    value               = substr(md5(local.envoy_config_content), 0, 8)
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}
