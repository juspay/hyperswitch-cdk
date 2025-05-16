resource "aws_security_group" "this" {
  name        = var.security_group_name
  description = "Security group for RDS ${var.db_name}"
  vpc_id      = var.vpc_id
  tags        = var.tags

  # Ingress rules will be added from where this module is called
  # (e.g., from app EC2/EKS security groups).
  # CDK adds ingress rule from lambdaSecurityGroup for standalone schema init.
}

resource "aws_db_subnet_group" "this" {
  name       = var.db_subnet_group_name == null ? "${var.stack_prefix}-${var.db_name}-sng" : var.db_subnet_group_name
  subnet_ids = var.database_zone_subnet_ids # These should be private subnets
  tags       = var.tags
}

# Standalone PostgreSQL Instance
resource "aws_db_instance" "standalone_db" {
  count = var.is_standalone_deployment ? 1 : 0

  identifier             = "${var.stack_prefix}-${var.db_name}-standalone"
  engine                 = "postgres"
  engine_version         = var.standalone_postgres_engine_version
  instance_class         = var.standalone_instance_type
  db_name                = var.db_name
  port                   = var.db_port
  username               = var.db_username # Password comes from secrets manager
  password               = data.aws_secretsmanager_secret_version.db_creds[0].secret_string # This is not ideal, RDS should use the secret ARN directly
  manage_master_user_password = true # Allows AWS to manage the password via Secrets Manager
  master_user_secret_kms_key_id = null # Use default AWS managed key for the secret unless specified

  vpc_security_group_ids = [aws_security_group.this.id]
  db_subnet_group_name   = aws_db_subnet_group.this.name
  
  allocated_storage     = 20 # Minimum for PostgreSQL, adjust as needed
  storage_type          = "gp2"
  publicly_accessible   = false
  skip_final_snapshot   = var.skip_final_snapshot
  backup_retention_period = 0 # Disable backups for free-tier like setup, adjust if needed
  multi_az              = false

  # CDK uses Credentials.fromSecret(secret), which means RDS integrates with Secrets Manager.
  # Terraform's aws_db_instance doesn't directly take a secret ARN for master credentials in the same way.
  # Instead, you can set manage_master_user_password = true and optionally master_user_secret_kms_key_id.
  # The password argument here is only for initial creation if not managed by SM.
  # For existing secrets, one might need to rotate the password via SM after creation if not using manage_master_user_password.
  # The CDK's `Credentials.fromSecret` is more seamless.
  # We will use `manage_master_user_password = true` and let RDS manage it with the secret.
  # The initial password in the secret will be used by RDS.

  apply_immediately = true # Or false, depending on maintenance window preferences
  tags              = var.tags

  # This depends_on is implicit due to secret_id usage, but explicit for clarity
  depends_on = [aws_secretsmanager_secret_version.db_creds_version] 
}

# Data source to retrieve the secret string if needed (e.g. for Lambda)
data "aws_secretsmanager_secret_version" "db_creds" {
  count     = var.is_standalone_deployment ? 1 : 0 # Only if standalone, as Aurora uses secret ARN directly
  secret_id = var.master_user_secret_arn
}


# Aurora PostgreSQL Cluster
resource "aws_rds_cluster" "aurora_db" {
  count = !var.is_standalone_deployment ? 1 : 0

  cluster_identifier              = "${var.stack_prefix}-${var.db_name}-aurora-cluster"
  engine                          = "aurora-postgresql"
  engine_version                  = var.aurora_postgres_engine_version
  database_name                   = var.db_name
  master_username                 = var.db_username # Password from SM
  manage_master_user_password     = true
  master_user_secret_kms_key_id   = null # Use default AWS managed key for the secret unless specified
  # master_password                 = data.aws_secretsmanager_secret_version.aurora_db_creds[0].secret_string # Not needed if manage_master_user_password = true
  port                            = var.db_port
  db_subnet_group_name            = aws_db_subnet_group.this.name
  vpc_security_group_ids          = [aws_security_group.this.id]
  skip_final_snapshot             = var.skip_final_snapshot
  backup_retention_period         = 7 # Default for Aurora, adjust as needed
  storage_encrypted               = var.storage_encrypted
  # apply_immediately             = true # For cluster parameter group changes etc.
  # db_cluster_parameter_group_name = "default.aurora-postgresql14" # Example

  tags = var.tags
  depends_on = [aws_secretsmanager_secret_version.aurora_db_creds_version]
}

resource "aws_rds_cluster_instance" "aurora_instances" {
  count = !var.is_standalone_deployment ? (1 + var.aurora_reader_count) : 0 # Writer + Readers

  identifier              = "${var.stack_prefix}-${var.db_name}-aurora-instance-${count.index}"
  cluster_identifier      = aws_rds_cluster.aurora_db[0].id
  instance_class          = count.index == 0 ? var.aurora_writer_instance_type : var.aurora_reader_instance_type
  engine                  = "aurora-postgresql"
  engine_version          = var.aurora_postgres_engine_version
  publicly_accessible     = false
  # db_subnet_group_name    = aws_db_subnet_group.this.name # Inherited from cluster
  # apply_immediately       = true
  # auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    InstanceType = count.index == 0 ? "writer" : "reader"
  })
}

# Data source for Aurora secret (not strictly needed for RDS resource itself if manage_master_user_password=true)
data "aws_secretsmanager_secret_version" "aurora_db_creds" {
  count     = !var.is_standalone_deployment ? 1 : 0
  secret_id = var.master_user_secret_arn
}

# --- Standalone RDS Schema Initialization (Lambda, S3, Trigger) ---
# This part replicates the CDK's custom resource logic for initializing the standalone DB.

# Lambda function to upload schema files from GitHub to S3 (as per CDK's inline Python)
resource "aws_lambda_function" "upload_schema_files_lambda" {
  count = var.create_schema_init_lambda_trigger ? 1 : 0

  function_name = "${var.stack_prefix}-UploadRdsSchemaFiles"
  handler       = "index.lambda_handler" # Assuming the Python code is in index.py
  runtime       = "python3.9"
  role          = var.lambda_role_arn_for_schema_init
  timeout       = 900 # 15 minutes

  # Inline code from CDK's uploadSchemaAndMigrationCode
  # This is a simplified representation. The actual Python code needs to be adapted.
  # It's better to package this as a zip file.
  filename = data.archive_file.upload_schema_zip[0].output_path
  source_code_hash = data.archive_file.upload_schema_zip[0].output_base64sha256

  environment = {
    variables = {
      # Variables needed by the Python script, e.g., S3 bucket name
      SCHEMA_BUCKET_NAME = var.rds_schema_s3_bucket_name,
      ACCOUNT_ID = data.aws_caller_identity.current.account_id, # If needed by script
      REGION = data.aws_region.current.name # If needed by script
    }
  }
  vpc_config {
    subnet_ids         = var.isolated_subnet_ids_for_lambda
    security_group_ids = [aws_security_group.this.id] # Lambda needs to access RDS SG if it connects directly
  }
  tags = var.tags
}

# Lambda function to initialize the DB using schema from S3
resource "aws_lambda_function" "initialize_db_lambda" {
  count = var.create_schema_init_lambda_trigger ? 1 : 0

  function_name = "${var.stack_prefix}-InitializeRdsDb"
  handler       = "index.db_handler" # Assuming migration_runner.zip contains index.py with db_handler
  runtime       = "python3.9"
  role          = var.lambda_role_arn_for_schema_init
  timeout       = 900 # 15 minutes

  s3_bucket = var.rds_schema_s3_bucket_name
  s3_key    = "migration_runner.zip" # As per CDK

  environment {
    variables = {
      DB_SECRET_ARN   = var.master_user_secret_arn
      SCHEMA_BUCKET   = var.rds_schema_s3_bucket_name
      SCHEMA_FILE_KEY = "schema.sql"
    }
  }
  vpc_config {
    subnet_ids         = var.isolated_subnet_ids_for_lambda
    security_group_ids = [aws_security_group.this.id] # Lambda needs to access RDS
  }
  tags = var.tags
  depends_on = [aws_lambda_function.upload_schema_files_lambda] # Ensure files are uploaded first
}

# Trigger for uploading schema files (simulating CDK's CustomResource for Create event)
resource "null_resource" "trigger_upload_schema_files" {
  count = var.create_schema_init_lambda_trigger ? 1 : 0

  triggers = {
    # Run on every apply if the lambda changes, or use a more specific trigger
    lambda_arn = aws_lambda_function.upload_schema_files_lambda[0].arn
  }

  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${aws_lambda_function.upload_schema_files_lambda[0].function_name} --payload '{\"RequestType\":\"Create\"}' response.json && cat response.json"
    # This is a basic invocation. Error handling and response parsing would be needed for robustness.
  }
  depends_on = [aws_lambda_function.upload_schema_files_lambda]
}


# Trigger for initializing DB (simulating CDK's Trigger.executeAfter)
resource "null_resource" "trigger_initialize_db" {
  count = var.create_schema_init_lambda_trigger && var.is_standalone_deployment ? 1 : 0

  triggers = {
    db_instance_endpoint = aws_db_instance.standalone_db[0].endpoint # Run when DB is available
    upload_trigger_done  = null_resource.trigger_upload_schema_files[0].id # Ensure upload is done
  }

  provisioner "local-exec" {
    # This should invoke the initialize_db_lambda
    command = "aws lambda invoke --function-name ${aws_lambda_function.initialize_db_lambda[0].function_name} response.json && cat response.json"
  }
  depends_on = [aws_db_instance.standalone_db, aws_lambda_function.initialize_db_lambda, null_resource.trigger_upload_schema_files]
}

# Data sources for Lambda code packaging (if not using inline)
data "archive_file" "upload_schema_zip" {
  count = var.create_schema_init_lambda_trigger ? 1 : 0
  type        = "zip"
  source_dir  = "lambda_code/upload_schema/" # Directory containing index.py for upload_schema_files_lambda
  output_path = "${path.module}/lambda_code/upload_schema.zip"
}

# (Need to create the actual Python scripts for these Lambdas based on CDK's inline code)
# Placeholder for AWS region and account ID data sources if needed by Lambda scripts
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Secret version dependencies for RDS resources
resource "aws_secretsmanager_secret_version" "db_creds_version" {
  count     = var.is_standalone_deployment ? 1 : 0
  secret_id = var.master_user_secret_arn
  # This resource is primarily to establish a dependency if the secret is managed outside this module
  # and its version needs to be current before RDS uses it.
  # If the secret module creates the version, RDS can depend on that module's output.
}

resource "aws_secretsmanager_secret_version" "aurora_db_creds_version" {
  count     = !var.is_standalone_deployment ? 1 : 0
  secret_id = var.master_user_secret_arn
}
