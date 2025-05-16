data "aws_ami" "amazon_linux_2_for_ib" {
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
  effective_base_ami_arn = var.base_ami_id == null ? data.aws_ami.amazon_linux_2_for_ib.arn : "arn:aws:ec2:${var.aws_region}::image/${var.base_ami_id}"

  # Component versions - CDK uses "1.0.1" for component and "1.0.3" for recipe.
  # These can be parameterized if needed.
  component_version = "1.0.1" 
  recipe_version    = "1.0.3" # Must be X.Y.Z format
}

# --- SNS Topics for Notifications ---
resource "aws_sns_topic" "squid_notification_topic" {
  name = "${var.stack_prefix}-ImgBuilderNotificationTopicSquid"
  tags = var.tags
}

resource "aws_sns_topic" "envoy_notification_topic" {
  name = "${var.stack_prefix}-ImgBuilderNotificationTopicEnvoy"
  tags = var.tags
}

resource "aws_sns_topic" "base_notification_topic" {
  name = "${var.stack_prefix}-ImgBuilderNotificationTopicBase"
  tags = var.tags
}

# --- Image Builder Components ---
resource "aws_imagebuilder_component" "squid_component" {
  name     = "${var.stack_prefix}SquidImageBuilder" # Matches CDK comp_name
  platform = "Linux"
  version  = local.component_version 
  data     = file("${path.module}/${var.squid_component_file_path}")
  # description = "Image builder for squid" # from CDK, can be added
  tags     = var.tags
}

resource "aws_imagebuilder_component" "envoy_component" {
  name     = "${var.stack_prefix}EnvoyImageBuilder"
  platform = "Linux"
  version  = local.component_version
  data     = file("${path.module}/${var.envoy_component_file_path}")
  tags     = var.tags
}

resource "aws_imagebuilder_component" "base_component" {
  name     = "${var.stack_prefix}BaseImageBuilder"
  platform = "Linux"
  version  = local.component_version
  data     = file("${path.module}/${var.base_component_file_path}")
  tags     = var.tags
}

# --- Image Builder Infrastructure Configurations ---
# One common infra config can be used if settings are the same, or define per pipeline.
# CDK creates one per pipeline.
resource "aws_imagebuilder_infrastructure_configuration" "squid_infra_config" {
  name                  = "${var.stack_prefix}SquidInfraConfig" # Matches CDK infra_config_name
  instance_types        = ["t3.medium"]
  instance_profile_name = var.iam_instance_profile_name
  sns_topic_arn         = aws_sns_topic.squid_notification_topic.arn
  subnet_id             = var.subnet_id_for_image_builder
  security_group_ids    = [var.security_group_id_for_image_builder]
  terminate_instance_on_failure = true # Good practice
  tags                  = var.tags
}

resource "aws_imagebuilder_infrastructure_configuration" "envoy_infra_config" {
  name                  = "${var.stack_prefix}EnvoyInfraConfig"
  instance_types        = ["t3.medium"]
  instance_profile_name = var.iam_instance_profile_name
  sns_topic_arn         = aws_sns_topic.envoy_notification_topic.arn
  subnet_id             = var.subnet_id_for_image_builder
  security_group_ids    = [var.security_group_id_for_image_builder]
  terminate_instance_on_failure = true
  tags                  = var.tags
}

resource "aws_imagebuilder_infrastructure_configuration" "base_infra_config" {
  name                  = "${var.stack_prefix}BaseInfraConfig"
  instance_types        = ["t3.medium"]
  instance_profile_name = var.iam_instance_profile_name
  sns_topic_arn         = aws_sns_topic.base_notification_topic.arn
  subnet_id             = var.subnet_id_for_image_builder
  security_group_ids    = [var.security_group_id_for_image_builder]
  terminate_instance_on_failure = true
  tags                  = var.tags
}

# --- Image Builder Recipes ---
resource "aws_imagebuilder_image_recipe" "squid_recipe" {
  name         = "${var.stack_prefix}SquidImageRecipe" # Matches CDK recipe_name
  parent_image = local.effective_base_ami_arn
  version      = local.recipe_version
  component {
    component_arn = aws_imagebuilder_component.squid_component.arn
  }
  # working_directory = "/tmp" # Optional
  tags = var.tags
}

resource "aws_imagebuilder_image_recipe" "envoy_recipe" {
  name         = "${var.stack_prefix}EnvoyImageRecipe"
  parent_image = local.effective_base_ami_arn
  version      = local.recipe_version
  component {
    component_arn = aws_imagebuilder_component.envoy_component.arn
  }
  tags = var.tags
}

resource "aws_imagebuilder_image_recipe" "base_recipe" {
  name         = "${var.stack_prefix}BaseImageRecipe"
  parent_image = local.effective_base_ami_arn # Or a more specific public AMI for base
  version      = local.recipe_version
  component {
    component_arn = aws_imagebuilder_component.base_component.arn
  }
  tags = var.tags
}

# --- Image Builder Pipelines ---
resource "aws_imagebuilder_image_pipeline" "squid_pipeline" {
  name                             = "${var.stack_prefix}SquidImagePipeline" # Matches CDK pipeline_name
  image_recipe_arn                 = aws_imagebuilder_image_recipe.squid_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.squid_infra_config.arn
  # schedule { # CDK doesn't define a schedule, so pipelines are manually triggered or via Lambda
  #   schedule_expression = "cron(0 0 1 * ? *)" # Example: Run monthly
  #   pipeline_execution_start_condition = "EXPRESSION_MATCH_AND_DEPENDENCY_UPDATES_AVAILABLE"
  # }
  status = "ENABLED" # Or "DISABLED"
  tags   = var.tags
}

resource "aws_imagebuilder_image_pipeline" "envoy_pipeline" {
  name                             = "${var.stack_prefix}EnvoyImagePipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.envoy_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.envoy_infra_config.arn
  status = "ENABLED"
  tags   = var.tags
}

resource "aws_imagebuilder_image_pipeline" "base_pipeline" {
  name                             = "${var.stack_prefix}BaseImagePipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.base_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.base_infra_config.arn
  status = "ENABLED"
  tags   = var.tags
}

# --- Lambda Functions ---
data "archive_file" "start_ib_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_code/start_ib.py"
  output_path = "${path.module}/lambda_code/start_ib.zip"
}

resource "aws_lambda_function" "start_ib_lambda" {
  function_name = "${var.stack_prefix}-IbStartLambda" # Matches CDK
  handler       = "start_ib.lambda_handler"
  runtime       = "python3.9"
  role          = var.lambda_role_arn_for_triggers
  timeout       = 900 # 15 minutes

  filename         = data.archive_file.start_ib_lambda_zip.output_path
  source_code_hash = data.archive_file.start_ib_lambda_zip.output_base64sha256

  environment {
    variables = {
      envoy_image_pipeline_arn = aws_imagebuilder_image_pipeline.envoy_pipeline.arn
      squid_image_pipeline_arn = aws_imagebuilder_image_pipeline.squid_pipeline.arn
      base_image_pipeline_arn  = aws_imagebuilder_image_pipeline.base_pipeline.arn
    }
  }
  tags = var.tags
}

# Custom Resource to trigger the start_ib_lambda on create/update
# This simulates CDK's CustomResource for triggering the Lambda.
resource "null_resource" "trigger_start_ib_lambda" {
  triggers = {
    # Run when any pipeline ARN changes, or on initial creation
    squid_pipeline_arn = aws_imagebuilder_image_pipeline.squid_pipeline.arn
    envoy_pipeline_arn = aws_imagebuilder_image_pipeline.envoy_pipeline.arn
    base_pipeline_arn  = aws_imagebuilder_image_pipeline.base_pipeline.arn
    lambda_function_arn = aws_lambda_function.start_ib_lambda.arn # Re-trigger if lambda changes
  }

  provisioner "local-exec" {
    # This command invokes the Lambda. The Lambda itself handles the CFN response for custom resources.
    # For Terraform, we just need to invoke it.
    command = <<EOT
aws lambda invoke \
  --function-name ${aws_lambda_function.start_ib_lambda.function_name} \
  --payload '{ "RequestType": "Create", "ResponseURL": "http://localhost", "StackId": "dummy", "RequestId": "dummy", "LogicalResourceId": "dummy" }' \
  response.json && cat response.json
EOT
    # The payload is a mock CFN event. The lambda is designed to handle it.
    # Consider error handling and response parsing for robustness.
  }
  depends_on = [aws_lambda_function.start_ib_lambda]
}


data "archive_file" "record_ami_lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_code/record_ami.py"
  output_path = "${path.module}/lambda_code/record_ami.zip"
}

resource "aws_lambda_function" "record_ami_squid" {
  function_name = "${var.stack_prefix}-RecordAmiIdSquid" # Matches CDK
  handler       = "record_ami.lambda_handler"
  runtime       = "python3.9"
  role          = var.lambda_role_arn_for_triggers
  timeout       = 900 # 15 minutes

  filename         = data.archive_file.record_ami_lambda_zip.output_path
  source_code_hash = data.archive_file.record_ami_lambda_zip.output_base64sha256

  environment {
    variables = {
      IMAGE_SSM_NAME = var.squid_ami_ssm_parameter_name
    }
  }
  tags = var.tags
}

resource "aws_lambda_function" "record_ami_envoy" {
  function_name = "${var.stack_prefix}-RecordAmiIdEnvoy"
  handler       = "record_ami.lambda_handler"
  runtime       = "python3.9"
  role          = var.lambda_role_arn_for_triggers
  timeout       = 900

  filename         = data.archive_file.record_ami_lambda_zip.output_path
  source_code_hash = data.archive_file.record_ami_lambda_zip.output_base64sha256

  environment {
    variables = {
      IMAGE_SSM_NAME = var.envoy_ami_ssm_parameter_name
    }
  }
  tags = var.tags
}

resource "aws_lambda_function" "record_ami_base" {
  function_name = "${var.stack_prefix}-RecordAmiIdBase"
  handler       = "record_ami.lambda_handler"
  runtime       = "python3.9"
  role          = var.lambda_role_arn_for_triggers
  timeout       = 900

  filename         = data.archive_file.record_ami_lambda_zip.output_path
  source_code_hash = data.archive_file.record_ami_lambda_zip.output_base64sha256

  environment {
    variables = {
      IMAGE_SSM_NAME = var.base_ami_ssm_parameter_name
    }
  }
  tags = var.tags
}

# --- SNS Subscriptions ---
resource "aws_sns_topic_subscription" "squid_lambda_subscription" {
  topic_arn = aws_sns_topic.squid_notification_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.record_ami_squid.arn
}

resource "aws_sns_topic_subscription" "envoy_lambda_subscription" {
  topic_arn = aws_sns_topic.envoy_notification_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.record_ami_envoy.arn
}

resource "aws_sns_topic_subscription" "base_lambda_subscription" {
  topic_arn = aws_sns_topic.base_notification_topic.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.record_ami_base.arn
}

# Permissions for SNS to invoke Lambda
resource "aws_lambda_permission" "allow_sns_to_squid_lambda" {
  statement_id  = "AllowExecutionFromSNSForSquid"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.record_ami_squid.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.squid_notification_topic.arn
}

resource "aws_lambda_permission" "allow_sns_to_envoy_lambda" {
  statement_id  = "AllowExecutionFromSNSForEnvoy"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.record_ami_envoy.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.envoy_notification_topic.arn
}

resource "aws_lambda_permission" "allow_sns_to_base_lambda" {
  statement_id  = "AllowExecutionFromSNSForBase"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.record_ami_base.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.base_notification_topic.arn
}
