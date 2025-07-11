# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ami" "amazon_linux_2023" {
  count       = var.ami_id == null ? 1 : 0
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

locals {
  base_image_id = var.ami_id != null ? var.ami_id : data.aws_ami.amazon_linux_2023[0].id
}

# VPC Configuration
resource "aws_vpc" "imagebuilder_vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "imagebuilder-vpc"
  }
}

resource "aws_internet_gateway" "imagebuilder_igw" {
  vpc_id = aws_vpc.imagebuilder_vpc.id

  tags = {
    Name = "imagebuilder-igw"
  }
}

resource "aws_subnet" "imagebuilder_public_subnet" {
  count             = var.az_count
  vpc_id            = aws_vpc.imagebuilder_vpc.id
  cidr_block        = "10.0.${count.index + 1}.0/24"
  availability_zone = data.aws_availability_zones.available.names[count.index]

  map_public_ip_on_launch = true

  tags = {
    Name = "imagebuilder-public-subnet-${count.index + 1}"
  }
}

resource "aws_route_table" "imagebuilder_public_rt" {
  vpc_id = aws_vpc.imagebuilder_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.imagebuilder_igw.id
  }

  tags = {
    Name = "imagebuilder-public-rt"
  }
}

resource "aws_route_table_association" "imagebuilder_public_rta" {
  count          = 2
  subnet_id      = aws_subnet.imagebuilder_public_subnet[count.index].id
  route_table_id = aws_route_table.imagebuilder_public_rt.id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Security Group
resource "aws_security_group" "image_server_sg" {
  name_prefix = "image-server-sg"
  vpc_id      = aws_vpc.imagebuilder_vpc.id
  description = "security group for a image builder server"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "image-server-sg"
  }
}

# SNS Topics
resource "aws_sns_topic" "envoy_notification" {
  name = "ImgBuilderNotificationTopicEnvoy"
}

resource "aws_sns_topic" "squid_notification" {
  name = "ImgBuilderNotificationTopicSquid"
}

resource "aws_sns_topic" "base_notification" {
  name = "ImgBuilderNotificationTopicBase"
}

# IAM Role for Image Builder
resource "aws_iam_role" "station_role" {
  name = "StationRole"

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

resource "aws_iam_role_policy_attachment" "station_role_ssm" {
  role       = aws_iam_role.station_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "station_role_imagebuilder" {
  role       = aws_iam_role.station_role.name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
}

# Instance Profiles
resource "aws_iam_instance_profile" "squid_station_profile" {
  name = "SquidStationInstanceProfile"
  role = aws_iam_role.station_role.name
}

resource "aws_iam_instance_profile" "envoy_station_profile" {
  name = "EnvoyStationProfile"
  role = aws_iam_role.station_role.name
}

resource "aws_iam_instance_profile" "base_station_profile" {
  name = "BaseStationProfile"
  role = aws_iam_role.station_role.name
}

# Image Builder Components
resource "aws_imagebuilder_component" "squid_component" {
  name        = "HyperswitchSquidImageBuilder"
  description = "Image builder for squid"
  platform    = "Linux"
  version     = "1.0.1"
  data        = file("${path.module}/components/squid.yml")
}

resource "aws_imagebuilder_component" "envoy_component" {
  name        = "HyperswitchEnvoyImageBuilder"
  description = "Image builder for Envoy"
  platform    = "Linux"
  version     = "1.0.1"
  data        = file("${path.module}/components/envoy.yml")
}

resource "aws_imagebuilder_component" "base_component" {
  name        = "HyperswitchBaseImageBuilder"
  description = "Image builder for Base Image"
  platform    = "Linux"
  version     = "1.0.1"
  data        = file("${path.module}/components/base.yml")
}

# Image Builder Recipes
resource "aws_imagebuilder_image_recipe" "squid_recipe" {
  name         = "SquidImageRecipe"
  parent_image = local.base_image_id
  version      = "1.0.4"

  component {
    component_arn = aws_imagebuilder_component.squid_component.arn
  }
}

resource "aws_imagebuilder_image_recipe" "envoy_recipe" {
  name         = "EnvoyImageRecipe"
  parent_image = local.base_image_id
  version      = "1.0.4"

  component {
    component_arn = aws_imagebuilder_component.envoy_component.arn
  }
}

resource "aws_imagebuilder_image_recipe" "base_recipe" {
  name         = "BaseImageRecipe"
  parent_image = local.base_image_id
  version      = "1.0.4"

  component {
    component_arn = aws_imagebuilder_component.base_component.arn
  }
}

# Infrastructure Configurations
resource "aws_imagebuilder_infrastructure_configuration" "squid_infra_config" {
  name                          = "SquidInfraConfig"
  instance_profile_name         = aws_iam_instance_profile.squid_station_profile.name
  instance_types                = ["t3.medium"]
  subnet_id                     = aws_subnet.imagebuilder_public_subnet[0].id
  security_group_ids            = [aws_security_group.image_server_sg.id]
  sns_topic_arn                 = aws_sns_topic.squid_notification.arn
  terminate_instance_on_failure = true

  depends_on = [aws_iam_instance_profile.squid_station_profile]
}

resource "aws_imagebuilder_infrastructure_configuration" "envoy_infra_config" {
  name                          = "EnvoyInfraConfig"
  instance_profile_name         = aws_iam_instance_profile.envoy_station_profile.name
  instance_types                = ["t3.medium"]
  subnet_id                     = aws_subnet.imagebuilder_public_subnet[0].id
  security_group_ids            = [aws_security_group.image_server_sg.id]
  sns_topic_arn                 = aws_sns_topic.envoy_notification.arn
  terminate_instance_on_failure = true

  depends_on = [aws_iam_instance_profile.envoy_station_profile]
}

resource "aws_imagebuilder_infrastructure_configuration" "base_infra_config" {
  name                          = "BaseInfraConfig"
  instance_profile_name         = aws_iam_instance_profile.base_station_profile.name
  instance_types                = ["t3.medium"]
  subnet_id                     = aws_subnet.imagebuilder_public_subnet[0].id
  security_group_ids            = [aws_security_group.image_server_sg.id]
  sns_topic_arn                 = aws_sns_topic.base_notification.arn
  terminate_instance_on_failure = true

  depends_on = [aws_iam_instance_profile.base_station_profile]
}

# Image Builder Pipelines
resource "aws_imagebuilder_image_pipeline" "squid_pipeline" {
  name                             = "SquidImagePipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.squid_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.squid_infra_config.arn
}

resource "aws_imagebuilder_image_pipeline" "envoy_pipeline" {
  name                             = "EnvoyImagePipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.envoy_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.envoy_infra_config.arn
}

resource "aws_imagebuilder_image_pipeline" "base_pipeline" {
  name                             = "BaseImagePipeline"
  image_recipe_arn                 = aws_imagebuilder_image_recipe.base_recipe.arn
  infrastructure_configuration_arn = aws_imagebuilder_infrastructure_configuration.base_infra_config.arn
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "hyperswitch-ib-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "ib-start-role"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["imagebuilder:StartImagePipelineExecution"]
        Resource = [
          "arn:aws:imagebuilder:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:image/*",
          "arn:aws:imagebuilder:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:image-pipeline/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["ssm:*"]
        Resource = ["*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Lambda Functions
resource "aws_lambda_function" "ib_start_lambda" {
  filename      = data.archive_file.start_ib_zip.output_path
  function_name = "HyperswitchIbStartLambda"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  timeout       = 900

  environment {
    variables = {
      envoy_image_pipeline_arn = aws_imagebuilder_image_pipeline.envoy_pipeline.arn
      squid_image_pipeline_arn = aws_imagebuilder_image_pipeline.squid_pipeline.arn
      base_image_pipeline_arn  = aws_imagebuilder_image_pipeline.base_pipeline.arn
    }
  }

  depends_on = [data.archive_file.start_ib_zip]
}

# Archive the Lambda code
data "archive_file" "start_ib_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda/start_ib.zip"

  source {
    content  = file("${path.module}/lambda/start_ib.py")
    filename = "index.py"
  }
}

data "archive_file" "record_ami_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda/record_ami.zip"

  source {
    content  = file("${path.module}/lambda/record_ami.py")
    filename = "index.py"
  }
}

# Custom Resource to trigger Lambda
resource "aws_lambda_invocation" "trigger_ib_start" {
  function_name = aws_lambda_function.ib_start_lambda.function_name
  input = jsonencode({
    trigger = "start-image-builder"
  })


  depends_on = [aws_lambda_function.ib_start_lambda]
}

# Record AMI Lambda Functions
resource "aws_lambda_function" "record_ami_squid" {
  filename      = data.archive_file.record_ami_zip.output_path
  function_name = "HyperswitchRecordAmiIdSquid"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  timeout       = 900

  environment {
    variables = {
      IMAGE_SSM_NAME = "squid_image_ami"
    }
  }

  depends_on = [data.archive_file.record_ami_zip]
}

resource "aws_lambda_function" "record_ami_envoy" {
  filename      = data.archive_file.record_ami_zip.output_path
  function_name = "HyperswitchRecordAmiIdEnvoy"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  timeout       = 900

  environment {
    variables = {
      IMAGE_SSM_NAME = "envoy_image_ami"
    }
  }

  depends_on = [data.archive_file.record_ami_zip]
}

resource "aws_lambda_function" "record_ami_base" {
  filename      = data.archive_file.record_ami_zip.output_path
  function_name = "HyperswitchRecordAmiIdBase"
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.lambda_handler"
  runtime       = "python3.9"
  timeout       = 900

  environment {
    variables = {
      IMAGE_SSM_NAME = "base_image_ami"
    }
  }

  depends_on = [data.archive_file.record_ami_zip]
}

# SNS Topic Subscriptions
resource "aws_sns_topic_subscription" "squid_lambda_subscription" {
  topic_arn = aws_sns_topic.squid_notification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.record_ami_squid.arn
}

resource "aws_sns_topic_subscription" "envoy_lambda_subscription" {
  topic_arn = aws_sns_topic.envoy_notification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.record_ami_envoy.arn
}

resource "aws_sns_topic_subscription" "base_lambda_subscription" {
  topic_arn = aws_sns_topic.base_notification.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.record_ami_base.arn
}

# Lambda permissions for SNS
resource "aws_lambda_permission" "allow_sns_squid" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.record_ami_squid.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.squid_notification.arn
}

resource "aws_lambda_permission" "allow_sns_envoy" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.record_ami_envoy.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.envoy_notification.arn
}

resource "aws_lambda_permission" "allow_sns_base" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.record_ami_base.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.base_notification.arn
}


