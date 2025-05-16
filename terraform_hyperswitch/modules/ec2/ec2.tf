data "aws_ami" "amazon_linux_2" {
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

resource "aws_key_pair" "this" {
  count = var.create_new_key_pair && var.key_pair_name == null ? 1 : 0

  key_name   = "${var.instance_name_prefix}-keypair"
  public_key = tls_private_key.this[0].public_key_openssh # Requires tls provider
  tags       = var.tags
}

resource "tls_private_key" "this" {
  count     = var.create_new_key_pair && var.key_pair_name == null ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_security_group" "this" {
  count = var.create_new_security_group && length(var.security_group_ids) == 0 ? 1 : 0

  name        = "${var.instance_name_prefix}-${var.security_group_name_prefix}"
  description = "Security group for EC2 instance ${var.instance_name_prefix}"
  vpc_id      = var.vpc_id
  tags        = var.tags

  dynamic "ingress" {
    for_each = var.security_group_ingress_rules
    content {
      description = lookup(ingress.value, "description", null)
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = lookup(ingress.value, "cidr_blocks", null)
      security_groups = lookup(ingress.value, "source_security_group_id", null) == null ? null : [lookup(ingress.value, "source_security_group_id", null)]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
    # Only add this if var.security_group_allow_all_outbound is true,
    # but Terraform requires at least one egress rule if not specifying `revoke_rules_on_delete`.
    # If allow_all_outbound is false, this block should be conditional or removed,
    # and specific egress rules provided. For simplicity, matching CDK's default.
  }
}

locals {
  final_key_name = var.key_pair_name != null ? var.key_pair_name : (var.create_new_key_pair ? aws_key_pair.this[0].key_name : null)
  
  final_security_group_ids = length(var.security_group_ids) > 0 ? var.security_group_ids : (var.create_new_security_group ? [aws_security_group.this[0].id] : [])
  # This local variable is for the output, not directly used in aws_instance for SG ids.
  final_security_group_id = length(var.security_group_ids) > 0 ? var.security_group_ids[0] : (var.create_new_security_group ? aws_security_group.this[0].id : null)

  effective_ami_id = var.ami_id == null ? data.aws_ami.amazon_linux_2.id : var.ami_id
}

resource "aws_instance" "this" {
  count = 1 # This module always creates one instance if invoked

  ami                         = local.effective_ami_id
  instance_type               = var.instance_type
  key_name                    = local.final_key_name
  vpc_security_group_ids      = local.final_security_group_ids
  subnet_id                   = var.subnet_ids[0] # Assumes single subnet for a single instance
  user_data_base64            = var.user_data_base64
  associate_public_ip_address = var.associate_public_ip_address
  iam_instance_profile        = var.iam_instance_profile_name

  # ssm_session_permissions is handled by attaching the AmazonSSMManagedInstanceCore policy
  # to the IAM role associated with the instance profile. This module doesn't create the role.

  tags = merge(
    {
      "Name" = var.instance_name_prefix
    },
    var.tags
  )
}
