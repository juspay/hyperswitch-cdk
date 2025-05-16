data "aws_ami" "amazon_linux_2_keymanager" {
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

locals {
  effective_keymanager_ec2_ami_id = var.keymanager_ec2_ami_id == null ? data.aws_ami.amazon_linux_2_keymanager.id : var.keymanager_ec2_ami_id
  env_file_s3_key                 = "keymanager_${lower(replace(var.keymanager_name, " ", "-"))}.env"
  db_name_formatted               = "keymanager_${lower(replace(var.keymanager_name, " ", "_"))}" # Ensure DB name is valid
}

# --- Keymanager Database (Aurora PostgreSQL) ---
resource "aws_security_group" "keymanager_db_sg" {
  name        = "${var.stack_prefix}-${var.keymanager_name}-db-SG"
  description = "Security group for Keymanager ${var.keymanager_name} RDS Aurora cluster"
  vpc_id      = var.vpc_id
  tags        = var.tags
}

resource "aws_db_subnet_group" "keymanager_db_sng" {
  name       = "${var.stack_prefix}-${var.keymanager_name}-db-sng"
  subnet_ids = var.keymanager_database_subnet_ids
  tags       = var.tags
}

resource "aws_rds_cluster" "keymanager_db" {
  cluster_identifier              = "${var.stack_prefix}-${lower(replace(var.keymanager_name, " ", "-"))}-db-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = var.keymanager_aurora_engine_version
  database_name                   = local.db_name_formatted
  master_username                 = var.keymanager_db_user
  manage_master_user_password     = true
  master_user_secret_kms_key_id   = var.keymanager_kms_key_arn # Encrypt SM secret with Keymanager's KMS key
  port                            = var.keymanager_db_port
  db_subnet_group_name            = aws_db_subnet_group.keymanager_db_sng.name
  vpc_security_group_ids          = [aws_security_group.keymanager_db_sg.id]
  skip_final_snapshot             = true
  backup_retention_period         = 7
  storage_encrypted               = true
  tags                            = var.tags
  # Explicit dependency on the secret version being available if RDS is to manage it.
  depends_on = [aws_secretsmanager_secret_version.keymanager_db_creds_version]
}

resource "aws_rds_cluster_instance" "keymanager_db_instance" {
  identifier              = "${var.stack_prefix}-${lower(replace(var.keymanager_name, " ", "-"))}-db-instance"
  cluster_identifier      = aws_rds_cluster.keymanager_db.id
  instance_class          = var.keymanager_aurora_instance_type
  engine                  = "aurora-postgresql"
  engine_version          = var.keymanager_aurora_engine_version
  publicly_accessible     = false
  tags                    = var.tags
}

# Dependency resource for Keymanager DB secret
resource "aws_secretsmanager_secret_version" "keymanager_db_creds_version" {
  secret_id = var.keymanager_db_secrets_manager_arn
  # This ensures that the secret (and its initial version if created by SM module) exists
  # before RDS tries to use it for manage_master_user_password.
}

# --- Lambda for KMS encryption of secrets and uploading .env to S3 ---
data "archive_file" "keymanager_kms_encrypt_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_code/encryption.py"
  output_path = "${path.module}/lambda_code/encryption.zip"
}

resource "aws_lambda_function" "keymanager_kms_encrypt_lambda" {
  function_name = "${var.stack_prefix}-${var.keymanager_name}-KmsEncryptionLambda"
  handler       = "encryption.lambda_handler"
  runtime       = "python3.9"
  role          = var.lambda_role_arn_for_kms_encryption
  timeout       = 900

  filename         = data.archive_file.keymanager_kms_encrypt_lambda_zip.output_path
  source_code_hash = data.archive_file.keymanager_kms_encrypt_lambda_zip.output_base64sha256

  vpc_config { # If Lambda needs to access VPC resources (e.g., Secrets Manager VPC endpoint)
    subnet_ids         = var.keymanager_server_subnet_ids # Or other appropriate subnets
    security_group_ids = [aws_security_group.keymanager_ec2_sg.id] # Or a dedicated Lambda SG
  }

  environment {
    variables = {
      SECRET_MANAGER_ARN = var.keymanager_secrets_manager_kms_data_arn
      ENV_BUCKET_NAME    = var.keymanager_env_s3_bucket_name
      ENV_FILE           = local.env_file_s3_key
    }
  }
  tags = var.tags
}

# Trigger for the KMS encryption Lambda
resource "null_resource" "trigger_keymanager_kms_encryption" {
  triggers = {
    lambda_arn    = aws_lambda_function.keymanager_kms_encrypt_lambda.arn
    secret_arn    = var.keymanager_secrets_manager_kms_data_arn
    # Add other triggers if the content of the secret changes and requires re-encryption.
    # e.g., keymanager_name, tls certs, master key if they are part of the secret and change.
    keymanager_name = var.keymanager_name 
  }
  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${aws_lambda_function.keymanager_kms_encrypt_lambda.function_name} --payload '{ \"RequestType\": \"Create\", \"ResponseURL\": \"http://localhost\", \"StackId\": \"dummy\", \"RequestId\": \"dummy\", \"LogicalResourceId\": \"dummy\" }' /dev/null"
  }
  depends_on = [aws_lambda_function.keymanager_kms_encrypt_lambda]
}

# --- Keymanager EC2 Instance ---
resource "aws_security_group" "keymanager_ec2_sg" {
  name        = "${var.stack_prefix}-${var.keymanager_name}-SG"
  description = "Security group for Keymanager ${var.keymanager_name} EC2 instance"
  vpc_id      = var.vpc_id
  tags        = var.tags
  # Ingress rules will be added from consuming services (e.g., EKS Hyperswitch App)
}

resource "aws_key_pair" "keymanager_ec2_key" {
  key_name   = "${var.stack_prefix}-${var.keymanager_name}-ec2-keypair"
  public_key = tls_private_key.keymanager_ec2_ssh.public_key_openssh
  tags       = var.tags
}

resource "tls_private_key" "keymanager_ec2_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  keymanager_ec2_userdata = templatefile("${path.module}/templates/userdata_keymanager_ec2.sh.tpl", {
    env_s3_bucket_name = var.keymanager_env_s3_bucket_name
    env_file_key       = local.env_file_s3_key
  })
}

resource "aws_instance" "keymanager_ec2" {
  ami                         = local.effective_keymanager_ec2_ami_id
  instance_type               = var.keymanager_ec2_instance_type
  key_name                    = aws_key_pair.keymanager_ec2_key.key_name
  subnet_id                   = var.keymanager_server_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.keymanager_ec2_sg.id]
  iam_instance_profile        = var.keymanager_iam_instance_profile_name
  user_data_base64            = base64encode(local.keymanager_ec2_userdata)
  associate_public_ip_address = false # Typically internal
  tags = merge(var.tags, { Name = "${var.stack_prefix}-${var.keymanager_name}-ec2" })

  depends_on = [null_resource.trigger_keymanager_kms_encryption] # Ensure .env file is uploaded
}

# Allow Keymanager EC2 to connect to Keymanager DB
resource "aws_security_group_rule" "keymanager_ec2_to_db" {
  type                     = "ingress"
  from_port                = var.keymanager_db_port
  to_port                  = var.keymanager_db_port
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.keymanager_ec2_sg.id
  security_group_id        = aws_security_group.keymanager_db_sg.id
  description              = "Allow Keymanager EC2 to connect to its DB"
}

# If Keymanager is deployed within EKS (as a Helm chart), this EC2 setup might be different
# or not needed if the Keymanager app runs as pods.
# The CDK code for Keymanager in EKS stack (lib/aws/eks.ts -> create_keymanager_stack)
# seems to imply it can be deployed as a separate stack (like this module) OR
# its configuration (TLS certs, etc.) is used by the main Hyperswitch app in EKS.
# This module assumes a standalone Keymanager stack with its own EC2 and RDS.
