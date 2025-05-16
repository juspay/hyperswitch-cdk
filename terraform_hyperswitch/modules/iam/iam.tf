# --- IAM Role and Instance Profile for EC2 Image Builder ---
resource "aws_iam_role" "image_builder_ec2_role" {
  count = var.create_image_builder_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-StationRole" # Matches CDK name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    "arn:aws:iam::aws:policy/EC2InstanceProfileForImageBuilder"
  ]
  tags = var.tags
}

# --- IAM Role and Instance Profile for Keymanager EC2 ---
resource "aws_iam_role" "keymanager_ec2_role" {
  count = var.create_keymanager_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-KeymanagerEC2Role" # Example name
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }] })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore", # For SSM access
    "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"      # For S3 access to .env file
  ]
  tags = var.tags
}

resource "aws_iam_instance_profile" "keymanager_ec2_profile" {
  count = var.create_keymanager_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-KeymanagerEC2Profile" # Example name
  role  = aws_iam_role.keymanager_ec2_role[0].name
  tags  = var.tags
}

resource "aws_iam_role_policy" "keymanager_ec2_kms_s3_sm_policy" {
  count = var.create_keymanager_ec2_role && var.keymanager_kms_key_arn_for_ec2_role != null && var.keymanager_env_bucket_arn_for_ec2_role != null ? 1 : 0
  name  = "${var.stack_prefix}-KeymanagerEC2KmsS3SmPolicy"
  role  = aws_iam_role.keymanager_ec2_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Action = "kms:Decrypt", Effect = "Allow", Resource = var.keymanager_kms_key_arn_for_ec2_role }, # For decrypting .env contents
      # Secrets Manager access might not be needed by EC2 if Lambda handles all SM interactions
      # { Action = "secretsmanager:GetSecretValue", Effect = "Allow", Resource = "*" }, 
      { Action = ["s3:GetObject"], Effect = "Allow", Resource = ["${var.keymanager_env_bucket_arn_for_ec2_role}/*"] } # Read .env file
    ]
  })
}

# --- IAM Role and Instance Profile for EKS Internal Jump EC2 ---
resource "aws_iam_role" "internal_jump_ec2_role" {
  count = var.create_internal_jump_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-InternalJumpEC2Role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }] })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" # For SSM access
  ]
  tags  = var.tags
}
resource "aws_iam_instance_profile" "internal_jump_ec2_profile" {
  count = var.create_internal_jump_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-InternalJumpEC2Profile"
  role  = aws_iam_role.internal_jump_ec2_role[0].name
  tags  = var.tags
}
# Note: The CDK's InternalJump construct doesn't explicitly add the detailed SessionManagerPolicies
# with KMS like the ExternalJump does. It relies on AmazonSSMManagedInstanceCore.

resource "aws_iam_instance_profile" "image_builder_ec2_profile" {
  count = var.create_image_builder_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-StationInstanceProfile" # Matches CDK CfnInstanceProfile name
  role  = aws_iam_role.image_builder_ec2_role[0].name
  tags  = var.tags
}

# --- IAM Role for EKS Node Groups ---
resource "aws_iam_role" "eks_nodegroup_role" {
  count = var.create_eks_nodegroup_role ? 1 : 0
  name  = "${var.stack_prefix}-HSNodegroupRole" # Matches CDK name
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
    # "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess", # CDK adds this, consider if needed
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy" # For EBS CSI Driver
  ]
  tags = var.tags
}

# EKS Node Group Role - CloudWatch Policy (from CDK)
resource "aws_iam_role_policy" "eks_nodegroup_cloudwatch_policy" {
  count = var.create_eks_nodegroup_role ? 1 : 0
  name  = "${var.stack_prefix}-HSCloudWatchPolicy"
  role  = aws_iam_role.eks_nodegroup_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = [
        "cloudwatch:DescribeAlarmsForMetric", "cloudwatch:DescribeAlarmHistory",
        "cloudwatch:DescribeAlarms", "cloudwatch:ListMetrics",
        "cloudwatch:GetMetricData", "cloudwatch:GetInsightRuleReport",
        "logs:DescribeLogGroups", "logs:GetLogGroupFields",
        "logs:StartQuery", "logs:StopQuery", "logs:GetQueryResults",
        "logs:GetLogEvents", "ec2:DescribeTags", "ec2:DescribeInstances",
        "ec2:DescribeRegions", "tag:GetResources"
      ],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

# EKS Node Group Role - AWS Load Balancer Controller Policy (fetched and inlined in CDK)
# For Terraform, it's better to use the managed policy or create a well-defined inline policy.
# Using the AWS managed policy for simplicity, or you can define the JSON from the CDK's fetch URL.
# data "http" "aws_lb_controller_iam_policy" {
#   count = var.create_eks_nodegroup_role ? 1 : 0
#   url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.1/docs/install/iam_policy.json" # Use appropriate version
# }
# resource "aws_iam_policy" "eks_lb_controller_policy" {
#   count = var.create_eks_nodegroup_role ? 1 : 0
#   name        = "${var.stack_prefix}-AWSLoadBalancerControllerIAMPolicy"
#   description = "IAM policy for AWS Load Balancer Controller"
#   policy      = data.http.aws_lb_controller_iam_policy[0].response_body
# }
# resource "aws_iam_role_policy_attachment" "eks_nodegroup_lb_controller_attach" {
#   count = var.create_eks_nodegroup_role ? 1 : 0
#   role       = aws_iam_role.eks_nodegroup_role[0].name
#   policy_arn = aws_iam_policy.eks_lb_controller_policy[0].arn
# }
# Simplified: Attach the AWS managed policy for ALB Ingress Controller (ensure it covers needs)
# Or, create the specific inline policy as per CDK's HSAWSLoadBalancerControllerIAMInlinePolicyInfo

# --- IAM Roles for EKS Service Accounts ---
# Hyperswitch Application Service Account Role
resource "aws_iam_role" "eks_hyperswitch_app_sa_role" {
  count = var.create_eks_service_account_roles && var.eks_oidc_provider_arn != null ? 1 : 0
  name  = "${var.stack_prefix}-HyperswitchServiceAccountRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = var.eks_oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(var.eks_oidc_provider_url, "https://", "")}:sub" = "system:serviceaccount:hyperswitch:hyperswitch-router-role", # Matches CDK
          "${replace(var.eks_oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "eks_hyperswitch_app_sa_policy" {
  count = var.create_eks_service_account_roles && var.eks_oidc_provider_arn != null && var.hyperswitch_kms_key_arn != null ? 1 : 0
  name  = "${var.stack_prefix}-HSAWSKMSKeyPolicy"
  role  = aws_iam_role.eks_hyperswitch_app_sa_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Action = ["kms:*"], Effect = "Allow", Resource = var.hyperswitch_kms_key_arn },
      { Action = ["elasticloadbalancing:DeleteLoadBalancer", "elasticloadbalancing:DescribeLoadBalancers"], Effect = "Allow", Resource = "*" },
      { Action = ["ssm:*"], Effect = "Allow", Resource = "*" },
      { Action = ["secretsmanager:*"], Effect = "Allow", Resource = "*" }
    ]
  })
}

# Grafana/Loki Service Account Role
resource "aws_iam_role" "eks_grafana_loki_sa_role" {
  count = var.create_eks_service_account_roles && var.eks_oidc_provider_arn != null ? 1 : 0
  name  = "${var.stack_prefix}-GrafanaServiceAccountRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = var.eks_oidc_provider_arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          # Matches CDK: "system:serviceaccount:loki:loki-grafana", "system:serviceaccount:loki:loki"
          "${replace(var.eks_oidc_provider_url, "https://", "")}:aud" = "sts.amazonaws.com"
        },
        # Terraform does not support list for :sub in StringEquals directly in one condition block.
        # This might need two roles or a more complex condition if strictly matching CDK.
        # For now, allowing both service accounts by creating a broader condition or separate roles.
        # Simplified: Assuming one role for both, or adjust if specific conditions are needed.
        "ForAnyValue:StringLike" = {
          "${replace(var.eks_oidc_provider_url, "https://", "")}:sub" = [
            "system:serviceaccount:loki:loki-grafana",
            "system:serviceaccount:loki:loki"
          ]
        }
      }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy" "eks_grafana_loki_sa_policy" {
  count = var.create_eks_service_account_roles && var.eks_oidc_provider_arn != null ? 1 : 0
  name  = "${var.stack_prefix}-GrafanaPolicy"
  role  = aws_iam_role.eks_grafana_loki_sa_role[0].id
  policy = jsonencode({ # Policy from CDK's grafanaPolicyDocument
    Version = "2012-10-17",
    Statement = [
      { Sid = "AllowReadingMetricsFromCloudWatch", Effect = "Allow", Action = ["cloudwatch:DescribeAlarmsForMetric", "cloudwatch:DescribeAlarmHistory", "cloudwatch:DescribeAlarms", "cloudwatch:ListMetrics", "cloudwatch:GetMetricData", "cloudwatch:GetInsightRuleReport"], Resource = "*" },
      { Sid = "AllowReadingLogsFromCloudWatch", Effect = "Allow", Action = ["logs:DescribeLogGroups", "logs:GetLogGroupFields", "logs:StartQuery", "logs:StopQuery", "logs:GetQueryResults", "logs:GetLogEvents"], Resource = "*" },
      { Sid = "AllowReadingTagsInstancesRegionsFromEC2", Effect = "Allow", Action = ["ec2:DescribeTags", "ec2:DescribeInstances", "ec2:DescribeRegions"], Resource = "*" },
      { Sid = "AllowReadingResourcesForTags", Effect = "Allow", Action = "tag:GetResources", Resource = "*" },
      { Sid = "AllowS3AccessForLoki", Effect = "Allow", Action = ["s3:ListBucket", "s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = [var.loki_s3_bucket_arn, "${var.loki_s3_bucket_arn}/*"] } # Added S3 for Loki
    ]
  })
}

# --- General IAM Role for Lambda Functions ---
resource "aws_iam_role" "lambda_general_role" {
  count = var.create_lambda_roles ? 1 : 0
  name  = "${var.stack_prefix}-LambdaGeneralRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"] # For VPC access
  tags                  = var.tags
}

resource "aws_iam_role_policy" "lambda_general_policy" {
  count = var.create_lambda_roles ? 1 : 0
  name  = "${var.stack_prefix}-LambdaGeneralPolicy"
  role  = aws_iam_role.lambda_general_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
      { Effect = "Allow", Action = "secretsmanager:GetSecretValue", Resource = distinct(compact(var.lambda_secrets_manager_arns)) },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = distinct(compact(var.lambda_s3_bucket_arns_for_put)) }, # Assumes PutObject implies GetObject for simplicity here
      { Effect = "Allow", Action = ["kms:Encrypt", "kms:Decrypt", "kms:GenerateDataKey*"], Resource = distinct(compact(var.lambda_kms_key_arns_for_usage)) },
      # For Image Builder Start Lambda
      { Effect = "Allow", Action = "imagebuilder:StartImagePipelineExecution", Resource = "arn:aws:imagebuilder:${var.aws_region}:${var.aws_account_id}:image-pipeline/*" },
      # For Image Builder Record AMI Lambda (SSM PutParameter)
      { Effect = "Allow", Action = "ssm:PutParameter", Resource = "arn:aws:ssm:${var.aws_region}:${var.aws_account_id}:parameter/*" } # Adjust path if more specific
    ]
  })
}

# --- IAM Role for Lambda triggering CodeBuild ---
resource "aws_iam_role" "lambda_codebuild_trigger_role" {
  count = var.create_codebuild_ecr_role && var.codebuild_project_arn_for_lambda_trigger != null ? 1 : 0
  name  = "${var.stack_prefix}-LambdaCodebuildTriggerRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
  managed_policy_arns = ["arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"]
  tags                  = var.tags
}
resource "aws_iam_role_policy" "lambda_codebuild_trigger_policy" {
  count = var.create_codebuild_ecr_role && var.codebuild_project_arn_for_lambda_trigger != null ? 1 : 0
  name  = "${var.stack_prefix}-LambdaCodebuildTriggerPolicy"
  role  = aws_iam_role.lambda_codebuild_trigger_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"], Resource = "arn:aws:logs:*:*:*" },
      { Effect = "Allow", Action = "codebuild:StartBuild", Resource = var.codebuild_project_arn_for_lambda_trigger }
    ]
  })
}


# --- IAM Role for CodeBuild ECR Image Transfer ---
resource "aws_iam_role" "codebuild_ecr_role" {
  count = var.create_codebuild_ecr_role ? 1 : 0
  name  = "${var.stack_prefix}-ECRRole" # Matches CDK
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" } }]
  })
  tags = var.tags
}
resource "aws_iam_role_policy" "codebuild_ecr_policy" {
  count = var.create_codebuild_ecr_role ? 1 : 0
  name  = "${var.stack_prefix}-ECRFullAccessPolicy" # Matches CDK
  role  = aws_iam_role.codebuild_ecr_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action   = ["ecr:CreateRepository", "ecr:CompleteLayerUpload", "ecr:GetAuthorizationToken", "ecr:UploadLayerPart", "ecr:InitiateLayerUpload", "ecr:BatchCheckLayerAvailability", "ecr:PutImage"],
      Effect   = "Allow",
      Resource = "*"
    }]
  })
}

# --- IAM Role and Instance Profile for External Jump EC2 ---
resource "aws_iam_role" "external_jump_ec2_role" {
  count = var.create_external_jump_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-ExternalJumpEC2Role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }] })
  tags  = var.tags
}
resource "aws_iam_instance_profile" "external_jump_ec2_profile" {
  count = var.create_external_jump_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-ExternalJumpEC2Profile"
  role  = aws_iam_role.external_jump_ec2_role[0].name
  tags  = var.tags
}
resource "aws_iam_role_policy" "external_jump_smm_policy" { # Matches SessionManagerPolicies from CDK
  count = var.create_external_jump_ec2_role && var.external_jump_ssm_kms_key_arn != null ? 1 : 0
  name  = "${var.stack_prefix}-SessionManagerPolicies"
  role  = aws_iam_role.external_jump_ec2_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Action = ["ssmmessages:CreateControlChannel", "ssmmessages:CreateDataChannel", "ssmmessages:OpenControlChannel", "ssmmessages:OpenDataChannel", "ssm:UpdateInstanceInformation"], Effect = "Allow", Resource = "*" },
      { Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogGroups", "logs:DescribeLogStreams"], Effect = "Allow", Resource = "*" },
      { Action = "s3:GetEncryptionConfiguration", Effect = "Allow", Resource = "*" },
      { Action = "kms:Decrypt", Effect = "Allow", Resource = var.external_jump_ssm_kms_key_arn },
      { Action = "kms:GenerateDataKey", Effect = "Allow", Resource = "*" } # CDK has "*", be more specific if possible
    ]
  })
}

# --- IAM Role and Instance Profile for Locker EC2 ---
resource "aws_iam_role" "locker_ec2_role" {
  count = var.create_locker_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-LockerEC2Role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }] })
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"] # As per CDK
  tags                  = var.tags
}
resource "aws_iam_instance_profile" "locker_ec2_profile" {
  count = var.create_locker_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-LockerEC2Profile"
  role  = aws_iam_role.locker_ec2_role[0].name
  tags  = var.tags
}
resource "aws_iam_role_policy" "locker_ec2_kms_s3_sm_policy" {
  count = var.create_locker_ec2_role && var.locker_kms_key_arn_for_ec2_role != null && var.locker_env_bucket_arn_for_ec2_role != null ? 1 : 0
  name  = "${var.stack_prefix}-LockerEC2KmsS3SmPolicy"
  role  = aws_iam_role.locker_ec2_role[0].id
  policy = jsonencode({ # Inline policy from CDK's locker_role
    Version = "2012-10-17",
    Statement = [
      { Action = "kms:*", Effect = "Allow", Resource = var.locker_kms_key_arn_for_ec2_role },
      { Action = "secretsmanager:*", Effect = "Allow", Resource = "*" }, # CDK uses "*", refine if possible
      { Action = "s3:PutObject", Effect = "Allow", Resource = ["${var.locker_env_bucket_arn_for_ec2_role}/*"] } # CDK has this, S3ReadOnlyAccess is also attached
    ]
  })
}

# --- IAM Role and Instance Profile for Envoy EC2 ---
resource "aws_iam_role" "envoy_ec2_role" {
  count = var.create_envoy_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-EnvoyEC2Role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }] })
  tags  = var.tags
}
resource "aws_iam_instance_profile" "envoy_ec2_profile" {
  count = var.create_envoy_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-EnvoyEC2Profile"
  role  = aws_iam_role.envoy_ec2_role[0].name
  tags  = var.tags
}
resource "aws_iam_role_policy" "envoy_ec2_s3_policy" {
  count = var.create_envoy_ec2_role && var.envoy_proxy_config_bucket_arn != null ? 1 : 0
  name  = "${var.stack_prefix}-EnvoyS3Policy"
  role  = aws_iam_role.envoy_ec2_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{ Action = "s3:GetObject", Effect = "Allow", Resource = "${var.envoy_proxy_config_bucket_arn}/*" }]
  })
}

# --- IAM Role and Instance Profile for Squid EC2 ---
resource "aws_iam_role" "squid_ec2_role" {
  count = var.create_squid_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-SquidEC2Role"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }] })
  tags  = var.tags
}
resource "aws_iam_instance_profile" "squid_ec2_profile" {
  count = var.create_squid_ec2_role ? 1 : 0
  name  = "${var.stack_prefix}-SquidEC2Profile"
  role  = aws_iam_role.squid_ec2_role[0].name
  tags  = var.tags
}
resource "aws_iam_role_policy" "squid_ec2_s3_policy" {
  count = var.create_squid_ec2_role && var.squid_proxy_config_bucket_arn != null && var.squid_logs_bucket_arn != null ? 1 : 0
  name  = "${var.stack_prefix}-SquidS3Policy"
  role  = aws_iam_role.squid_ec2_role[0].id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Action = ["s3:GetObject"], Effect = "Allow", Resource = "${var.squid_proxy_config_bucket_arn}/*" }, # For config
      { Action = ["s3:PutObject", "s3:GetObject", "s3:ListBucket"], Effect = "Allow", Resource = ["${var.squid_logs_bucket_arn}/*", var.squid_logs_bucket_arn] } # For logs
    ]
  })
}

# --- IAM Role for EKS Cluster ---
resource "aws_iam_role" "eks_cluster_role" {
  count = var.create_eks_cluster_role ? 1 : 0
  name  = "${var.stack_prefix}-EKSClusterRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
  })
  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
    # "arn:aws:iam::aws:policy/AmazonEKSServicePolicy" # Sometimes needed, CDK might attach it implicitly or via other constructs.
                                                     # AmazonEKSClusterPolicy is usually sufficient for the cluster itself.
  ]
  tags = var.tags
}
