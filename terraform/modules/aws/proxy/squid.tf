# ===== SQUID PROXY INFRASTRUCTURE =====

locals {
  squid_userdata_content = replace(
    replace(
      file("${path.module}/userdata/squid_userdata.sh"),
      "{{bucket-name}}", aws_s3_bucket.proxy_config.bucket
    ),
    "{{squid-logs-bucket}}", aws_s3_bucket.squid_logs_bucket.bucket
  )
}


# S3 Bucket for Squid Logs
resource "aws_s3_bucket" "squid_logs_bucket" {
  bucket = "${var.stack_name}-squid-proxy-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"

  force_destroy = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-squid-proxy-logs-${data.aws_caller_identity.current.account_id}-${data.aws_region.current.name}"
  })
}

# S3 Bucket Public Access Block
resource "aws_s3_bucket_public_access_block" "squid_logs_bucket_pab" {
  bucket = aws_s3_bucket.squid_logs_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Server Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "squid_logs_bucket_encryption" {
  bucket = aws_s3_bucket.squid_logs_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Upload Squid configuration files to S3
resource "aws_s3_object" "squid_config_files" {
  for_each = fileset("${path.module}/configurations/squid", "**")

  bucket = aws_s3_bucket.proxy_config.bucket
  key    = "squid/${each.value}"
  source = "${path.module}/configurations/squid/${each.value}"
}

# IAM Role for Squid Instances
resource "aws_iam_role" "squid_instance_role" {
  name = "${var.stack_name}-squid-instance-role"

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

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-squid-instance-role"
  })
}

# Attach AWS managed policy for SSM
resource "aws_iam_role_policy_attachment" "squid_ssm_policy" {
  role       = aws_iam_role.squid_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom policy for proxy config bucket read access
resource "aws_iam_role_policy" "squid_proxy_config_policy" {
  name = "${var.stack_name}-squid-proxy-config-policy"
  role = aws_iam_role.squid_instance_role.id

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
          aws_s3_bucket.proxy_config.arn,
          "${aws_s3_bucket.proxy_config.arn}/*"
        ]
      }
    ]
  })
}

# Custom policy for squid logs bucket read/write access
resource "aws_iam_role_policy" "squid_logs_policy" {
  name = "${var.stack_name}-squid-logs-policy"
  role = aws_iam_role.squid_instance_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = [
          aws_s3_bucket.squid_logs_bucket.arn,
          "${aws_s3_bucket.squid_logs_bucket.arn}/*"
        ]
      }
    ]
  })
}

# IAM Instance Profile for Squid
resource "aws_iam_instance_profile" "squid_instance_profile" {
  name = "${var.stack_name}-squid-instance-profile"
  role = aws_iam_role.squid_instance_role.name
}

# Generate an RSA key pair locally
resource "tls_private_key" "squid" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Key Pair for Squid instances
resource "aws_key_pair" "squid_key_pair" {
  key_name   = "${var.stack_name}-squid-proxy-keypair-${data.aws_region.current.name}"
  public_key = tls_private_key.squid.public_key_openssh
}

# save the private key to a local file
resource "local_file" "squid_private_key" {
  filename        = "${path.module}/squid_public_key.pem"
  content         = tls_private_key.squid.private_key_pem
  file_permission = "0600"
}

# Launch Template for Squid instances
resource "aws_launch_template" "squid_launch_template" {
  name_prefix   = "${var.stack_name}-squid-launch-template-"
  image_id      = var.squid_image_ami
  instance_type = "t3.medium"
  key_name      = aws_key_pair.squid_key_pair.key_name

  vpc_security_group_ids = [aws_security_group.squid_asg_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.squid_instance_profile.name
  }

  user_data = base64encode(local.squid_userdata_content)

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.common_tags, {
      Name = "${var.stack_name}-squid-proxy-instance"
    })
  }
}

# Auto Scaling Group for Squid
resource "aws_autoscaling_group" "squid_asg" {
  name                = "${var.stack_name}-squid-asg"
  vpc_zone_identifier = var.subnet_ids["outgoing_proxy_zone"]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.squid_launch_template.id
    version = "$Latest"
  }

  target_group_arns = [var.squid_target_group_arn]
  health_check_type = "ELB"

  depends_on = [aws_s3_object.squid_config_files]

  tag {
    key                 = "Name"
    value               = "${var.stack_name}-squid-asg"
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













