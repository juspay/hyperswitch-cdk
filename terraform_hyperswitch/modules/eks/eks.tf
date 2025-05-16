# --- EKS Cluster ---
resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = var.eks_cluster_role_arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.eks_control_plane_subnet_ids
    endpoint_private_access = var.endpoint_private_access
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  enabled_cluster_log_types = var.cluster_enabled_log_types

  tags = merge(var.tags, {
    "Name" = var.cluster_name
  })
}

# --- IAM OIDC Provider for EKS ---
resource "aws_iam_openid_connect_provider" "this" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks_oidc_thumbprint.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  tags            = var.tags
}

data "tls_certificate" "eks_oidc_thumbprint" {
  url = replace(aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")
}

# --- ECR Image Transfer ---
resource "aws_codebuild_project" "ecr_image_transfer" {
  count         = var.enable_ecr_image_transfer ? 1 : 0
  name          = "${var.stack_prefix}-ECRImageTransfer"
  description   = "Transfers Docker images to ECR"
  service_role  = var.codebuild_ecr_role_arn
  artifacts { type = "NO_ARTIFACTS" }
  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type                        = "LINUX_CONTAINER"
    privileged_mode             = true
    image_pull_credentials_type = "CODEBUILD"
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = var.aws_account_id
    }
    environment_variable {
      name  = "AWS_DEFAULT_REGION"
      value = var.aws_region
    }
  }
  source {
    type      = "NO_SOURCE"
    buildspec = file("${path.module}/codebuild_scripts/buildspec.yml")
  }
  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }
  tags = var.tags
}

data "archive_file" "start_ecr_transfer_lambda_zip" {
  count       = var.enable_ecr_image_transfer ? 1 : 0
  type        = "zip"
  source_file = "${path.module}/lambda_code/start_ecr_image_transfer_build.py"
  output_path = "${path.module}/lambda_code/start_ecr_image_transfer_build.zip"
}

resource "aws_lambda_function" "trigger_ecr_image_transfer_build" {
  count = var.enable_ecr_image_transfer ? 1 : 0
  function_name    = "${var.stack_prefix}-ECRImageTransferLambda"
  handler          = "start_ecr_image_transfer_build.lambda_handler"
  runtime          = "python3.9"
  role             = var.lambda_role_arn_for_codebuild_trigger
  timeout          = 900
  filename         = data.archive_file.start_ecr_transfer_lambda_zip[0].output_path
  source_code_hash = data.archive_file.start_ecr_transfer_lambda_zip[0].output_base64sha256
  environment { variables = { PROJECT_NAME = aws_codebuild_project.ecr_image_transfer[0].name } }
  vpc_config {
    subnet_ids         = var.eks_worker_nodes_one_zone_subnet_ids # Ensure these subnets have NAT access for boto3 calls if not using VPC endpoints
    security_group_ids = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id] # Or a more specific Lambda SG
  }
  tags = var.tags
}

resource "null_resource" "invoke_ecr_image_transfer_build_trigger" {
  count = var.enable_ecr_image_transfer ? 1 : 0
  triggers = { lambda_arn = aws_lambda_function.trigger_ecr_image_transfer_build[0].arn, codebuild_arn = aws_codebuild_project.ecr_image_transfer[0].arn }
  provisioner "local-exec" {
    command = "aws lambda invoke --function-name ${aws_lambda_function.trigger_ecr_image_transfer_build[0].function_name} --payload '{ \"RequestType\": \"Create\", \"ResponseURL\": \"http://localhost\", \"StackId\": \"dummy\", \"RequestId\": \"dummy\", \"LogicalResourceId\": \"dummy\" }' /dev/null"
  }
  depends_on = [aws_lambda_function.trigger_ecr_image_transfer_build, aws_codebuild_project.ecr_image_transfer]
}

# --- EKS Secrets Encryption Lambda ---
data "archive_file" "eks_secrets_encryption_lambda_zip" {
  type        = "zip", source_file = "${path.module}/lambda_code/eks_secrets_encryption.py", output_path = "${path.module}/lambda_code/eks_secrets_encryption.zip"
}
resource "aws_lambda_function" "eks_kms_encrypt_lambda" {
  function_name = "${var.stack_prefix}-HyperswitchKmsEncryptionLambda", handler = "eks_secrets_encryption.lambda_handler", runtime = "python3.9", role = var.lambda_role_arn_for_kms_encryption, timeout = 900
  filename = data.archive_file.eks_secrets_encryption_lambda_zip.output_path, source_code_hash = data.archive_file.eks_secrets_encryption_lambda_zip.output_base64sha256
  environment { variables = { SECRET_MANAGER_ARN = var.hyperswitch_app_secrets_manager_arn } }, tags = var.tags
}
resource "null_resource" "trigger_eks_kms_encryption_lambda" {
  triggers = { lambda_arn = aws_lambda_function.eks_kms_encrypt_lambda.arn, secret_arn = var.hyperswitch_app_secrets_manager_arn }
  provisioner "local-exec" { command = "aws lambda invoke --function-name ${aws_lambda_function.eks_kms_encrypt_lambda.function_name} --payload '{ \"RequestType\": \"Create\", \"ResponseURL\": \"http://localhost\", \"StackId\": \"dummy\", \"RequestId\": \"dummy\", \"LogicalResourceId\": \"dummy\" }' /dev/null" }
  depends_on = [aws_lambda_function.eks_kms_encrypt_lambda]
}

# --- EKS Node Groups ---
locals {
  nodegroups_config = {
    "HSNodegroup"               = { instance_types = ["t3.medium", "t3.medium"], min = 1, max = 3, desired = 2, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "generic-compute" } }
    "HSAutopilotNodegroup"      = { instance_types = ["t3.medium"], min = 1, max = 2, desired = 1, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "service" = "autopilot", "node-type" = "autopilot-od" } }
    "HSCkhZookeeperNodegroup"   = { instance_types = var.nodegroup_instance_types, min = 3, max = 8, desired = 3, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "ckh-zookeeper-compute" } },
    "HSCkhcomputeNodegroup"     = { instance_types = var.nodegroup_instance_types, min = 2, max = 3, desired = 2, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "clickhouse-compute" } },
    "HSControlcentreNodegroup"  = { instance_types = ["t3.medium"], min = 1, max = 5, desired = 1, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "control-center" } },
    "HSKafkacomputeNodegroup"   = { instance_types = var.nodegroup_instance_types, min = 3, max = 6, desired = 3, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "kafka-compute" } },
    "HSMemoryoptimizeNodegroup" = { instance_types = ["t3.medium"], min = 1, max = 5, desired = 2, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "memory-optimized" } },
    "HSMonitoringNodegroup"     = { instance_types = ["t3.medium"], min = 3, max = 63, desired = 6, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "monitoring" } },
    "HSPomeriumNodegroup"       = { instance_types = ["t3.medium"], min = 2, max = 2, desired = 2, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "service" = "pomerium", "node-type" = "pomerium", "function" = "SSO" } },
    "HSSystemNodegroup"         = { instance_types = ["t3.medium"], min = 1, max = 5, desired = 1, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "system-nodes" } },
    "HSUtilsNodegroup"          = { instance_types = ["t3.medium"], min = 5, max = 8, desired = 5, subnets_key = "utils_zone_subnet_ids", labels = { "node-type" = "elasticsearch" } },
    "HSZkcomputeNodegroup"      = { instance_types = var.nodegroup_instance_types, min = 3, max = 10, desired = 3, subnets_key = "eks_worker_nodes_one_zone_subnet_ids", labels = { "node-type" = "zookeeper-compute" } }
  }
}

resource "aws_eks_node_group" "this" {
  for_each        = local.nodegroups_config
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = each.key
  node_role_arn   = var.eks_nodegroup_role_arn
  subnet_ids      = lookup(var, each.value.subnets_key, var.eks_worker_nodes_one_zone_subnet_ids)
  scaling_config {
    desired_size = each.value.desired
    max_size     = each.value.max
    min_size     = each.value.min
  }
  instance_types = each.value.instance_types
  labels         = each.value.labels
  capacity_type  = "ON_DEMAND"
  update_config {
    max_unavailable_percentage = 50
  }
  tags = merge(var.tags, { "Name" = "${var.stack_prefix}-${each.key}" })
  depends_on = [aws_eks_cluster.this, aws_iam_openid_connect_provider.this, null_resource.invoke_ecr_image_transfer_build_trigger]
}

# --- Security Groups for Load Balancers ---
resource "aws_security_group" "eks_lb_sg" {
  name        = "${var.stack_prefix}-hs-loadbalancer-sg"
  description = "Security group for EKS LBs"
  vpc_id      = var.vpc_id
  tags        = var.tags
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_eks_cluster.this.vpc_config[0].cluster_security_group_id]
  }
}
resource "aws_security_group_rule" "cluster_ingress_from_lb_sg" {
  type                     = "ingress"
  from_port                = 0
  to_port                  = 0
  protocol                 = "-1"
  source_security_group_id = aws_security_group.eks_lb_sg.id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  description              = "Allow EKS LB to cluster"
}
resource "aws_security_group" "grafana_ingress_lb_sg" {
  name        = "${var.stack_prefix}-grafana-ingress-lb"
  description = "SG for Grafana Ingress LB"
  vpc_id      = var.vpc_id
  tags        = var.tags
  dynamic "ingress" {
    for_each = var.public_access_cidrs
    content {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }
  dynamic "ingress" {
    for_each = var.public_access_cidrs
    content {
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_security_group_rule" "cluster_ingress_from_grafana_lb_sg_3000" {
  type                     = "ingress"
  from_port                = 3000
  to_port                  = 3000
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}
resource "aws_security_group_rule" "cluster_ingress_from_grafana_lb_sg_80" {
  type                     = "ingress"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.grafana_ingress_lb_sg.id
  security_group_id        = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

# --- SDK CloudFront ---
resource "aws_cloudfront_origin_access_identity" "sdk_oai" {
  comment = "OAI for ${var.sdk_s3_bucket_name}"
}
resource "aws_cloudfront_distribution" "sdk_distribution" {
  count = 1
  origin {
    domain_name = "${var.sdk_s3_bucket_name}.s3.${var.aws_region}.amazonaws.com"
    origin_id   = "S3-${var.sdk_s3_bucket_name}"
    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.sdk_oai.cloudfront_access_identity_path
    }
  }
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CloudFront for SDK"
  default_root_object = "index.html"
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${var.sdk_s3_bucket_name}"
    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }
  price_class = "PriceClass_100"
  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  viewer_certificate {
    cloudfront_default_certificate = true
  }
  tags = var.tags
}

# --- Core Helm Charts ---
resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  version    = var.aws_load_balancer_controller_chart_version
  namespace  = "kube-system"
  set {
    name  = "clusterName"
    value = aws_eks_cluster.this.name
  }
  set {
    name  = "serviceAccount.create"
    value = "false"
  }
  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }
  set {
    name  = "image.repository"
    value = "${var.private_ecr_repository_prefix}/eks/aws-load-balancer-controller"
  }
  set {
    name  = "image.tag"
    value = "v2.12.0"
  }
  set {
    name  = "enableServiceMutatorWebhook"
    value = "false"
  }
  set {
    name  = "extraArgs.aws-region"
    value = var.aws_region
  }
  set {
    name  = "extraArgs.aws-vpc-id"
    value = var.vpc_id
  }
  depends_on = [aws_eks_cluster.this, aws_iam_openid_connect_provider.this, null_resource.invoke_ecr_image_transfer_build_trigger]
}
resource "helm_release" "ebs_csi_driver" {
  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  version    = var.ebs_csi_driver_chart_version
  namespace  = "kube-system"
  set {
    name  = "controller.serviceAccount.create"
    value = "false"
  }
  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }
  set {
    name  = "image.repository"
    value = "${var.private_ecr_repository_prefix}/ebs-csi-driver/aws-ebs-csi-driver"
  }
  set {
    name  = "image.tag"
    value = "v1.41.0"
  }
  set {
    name  = "sidecars.provisioner.image.repository"
    value = "${var.private_ecr_repository_prefix}/eks-distro/kubernetes-csi/external-provisioner"
  }
  set {
    name  = "sidecars.provisioner.image.tag"
    value = "v5.2.0-eks-1-32-10"
  }
  set {
    name  = "sidecars.attacher.image.repository"
    value = "${var.private_ecr_repository_prefix}/eks-distro/kubernetes-csi/external-attacher"
  }
  set {
    name  = "sidecars.attacher.image.tag"
    value = "v4.8.1-eks-1-32-10"
  }
  set {
    name  = "sidecars.snapshotter.image.repository"
    value = "${var.private_ecr_repository_prefix}/eks-distro/kubernetes-csi/external-snapshotter/csi-snapshotter"
  }
  set {
    name  = "sidecars.snapshotter.image.tag"
    value = "v8.2.1-eks-1-32-10"
  }
  set {
    name  = "sidecars.livenessProbe.image.repository"
    value = "${var.private_ecr_repository_prefix}/eks-distro/kubernetes-csi/livenessprobe"
  }
  set {
    name  = "sidecars.livenessProbe.image.tag"
    value = "v2.15.0-eks-1-32-10"
  }
  set {
    name  = "sidecars.resizer.image.repository"
    value = "${var.private_ecr_repository_prefix}/eks-distro/kubernetes-csi/external-resizer"
  }
  set {
    name  = "sidecars.resizer.image.tag"
    value = "v1.13.2-eks-1-32-10"
  }
  set {
    name  = "sidecars.nodeDriverRegistrar.image.repository"
    value = "${var.private_ecr_repository_prefix}/eks-distro/kubernetes-csi/node-driver-registrar"
  }
  set {
    name  = "sidecars.nodeDriverRegistrar.image.tag"
    value = "v2.13.0-eks-1-32-10"
  }
  set {
    name  = "sidecars.volumemodifier.image.repository"
    value = "${var.private_ecr_repository_prefix}/ebs-csi-driver/volume-modifier-for-k8s"
  }
  set {
    name  = "sidecars.volumemodifier.image.tag"
    value = "v0.5.1"
  }
  depends_on = [aws_eks_cluster.this, null_resource.invoke_ecr_image_transfer_build_trigger]
}
resource "helm_release" "istio_base" {
  name             = "istio-base"
  repository       = "https://istio-release.storage.googleapis.com/charts"
  chart            = "base"
  version          = var.istio_base_chart_version
  namespace        = "istio-system"
  create_namespace = true
  set {
    name  = "defaultRevision"
    value = "default"
  }
  depends_on = [aws_eks_cluster.this, null_resource.invoke_ecr_image_transfer_build_trigger]
}
resource "helm_release" "istiod" {
  name       = "istiod"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "istiod"
  version    = var.istio_istiod_chart_version
  namespace  = "istio-system"
  values = [yamlencode({
    global = {
      hub = var.private_ecr_repository_prefix
      tag = var.istio_istiod_chart_version
    }
    pilot = {
      nodeSelector = {
        "node-type" = "memory-optimized"
      }
    }
  })]
  depends_on = [helm_release.istio_base]
}
resource "helm_release" "istio_ingress_gateway" {
  name       = "istio-ingressgateway"
  repository = "https://istio-release.storage.googleapis.com/charts"
  chart      = "gateway"
  version    = var.istio_gateway_chart_version
  namespace  = "istio-system"
  values = [yamlencode({
    global = {
      hub = var.private_ecr_repository_prefix
      tag = var.istio_gateway_chart_version
    }
    service = {
      type = "ClusterIP"
    }
    nodeSelector = {
      "node-type" = "memory-optimized"
    }
  })]
  depends_on = [helm_release.istiod]
}
resource "helm_release" "metrics_server" {
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = var.metrics_server_chart_version
  namespace  = "kube-system"
  set {
    name  = "image.repository"
    value = "${var.private_ecr_repository_prefix}/bitnami/metrics-server"
  }
  set {
    name  = "image.tag"
    value = "0.7.2"
  }
  depends_on = [aws_eks_cluster.this, null_resource.invoke_ecr_image_transfer_build_trigger]
}

# --- Hyperswitch Application Helm Chart ---
data "aws_ssm_parameter" "kms_admin_api_key" {
  name       = "/hyperswitch/admin-api-key"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_jwt_secret" {
  name       = "/hyperswitch/jwt-secret"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_encrypted_db_pass" {
  name       = "/hyperswitch/db-pass"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_encrypted_master_key" {
  name       = "/hyperswitch/master-key"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_locker_public_key" {
  name       = "/hyperswitch/locker-public-key"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_tenant_private_key" {
  name       = "/hyperswitch/tenant-private-key"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_dummy_val" { # For multiple dummy values
  name       = "/hyperswitch/dummy-val"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_encrypted_api_hash_key" {
  name       = "/hyperswitch/kms-encrypted-api-hash-key"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_google_pay_root_signing_keys" {
  name       = "/hyperswitch/google-pay-root-signing-keys"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_paze_private_key" {
  name       = "/hyperswitch/paze-private-key"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
data "aws_ssm_parameter" "kms_paze_private_key_passphrase" {
  name       = "/hyperswitch/paze-private-key-passphrase"
  depends_on = [null_resource.trigger_eks_kms_encryption_lambda]
}
# Add more data sources for other specific SSM parameters as needed by the helm chart values template

resource "helm_release" "hyperswitch_services" {
  name               = "hypers-v1"
  repository         = "https://juspay.github.io/hyperswitch-helm/"
  chart              = "hyperswitch-stack"
  version            = var.hyperswitch_stack_chart_version
  namespace          = "hyperswitch"
  create_namespace   = true
  wait               = false
  values = [templatefile("${path.module}/helm_values/hyperswitch-stack-values.yaml.tpl", {
    cluster_name                     = aws_eks_cluster.this.name
    lb_security_group_id             = aws_security_group.eks_lb_sg.id
    private_ecr_prefix               = var.private_ecr_repository_prefix
    sdk_cloudfront_domain            = aws_cloudfront_distribution.sdk_distribution[0].domain_name
    sdk_version                      = var.sdk_version_for_helm
    sdk_subversion                   = var.sdk_subversion_for_helm
    aws_region                       = var.aws_region
    logs_bucket_name                 = "logs-bucket-${var.aws_account_id}-${var.aws_region}"
    hyperswitch_sa_role_arn          = var.hyperswitch_app_sa_role_arn
    kms_admin_api_key                = data.aws_ssm_parameter.kms_admin_api_key.value
    kms_jwt_secret                   = data.aws_ssm_parameter.kms_jwt_secret.value
    kms_encrypted_db_pass            = data.aws_ssm_parameter.kms_encrypted_db_pass.value
    kms_encrypted_master_key         = data.aws_ssm_parameter.kms_encrypted_master_key.value
    kms_key_id_for_app               = replace(var.hyperswitch_app_kms_key_arn, "arn:aws:kms:${var.aws_region}:${var.aws_account_id}:key/", "") # Extract Key ID from ARN
    db_password_plain                = var.rds_db_password
    rds_primary_host                 = var.rds_cluster_endpoint
    rds_readonly_host                = var.rds_cluster_reader_endpoint
    redis_host                       = var.elasticache_cluster_address
    locker_public_key_pem            = var.locker_public_key_pem != "locker-key" ? var.locker_public_key_pem : data.aws_ssm_parameter.kms_locker_public_key.value # Fallback to SSM if default
    tenant_private_key_pem           = var.tenant_private_key_pem != "locker-key" ? var.tenant_private_key_pem : data.aws_ssm_parameter.kms_tenant_private_key.value # Fallback to SSM if default
    locker_enabled                   = var.locker_public_key_pem != "locker-key"
    # Pass other SSM values
    kms_jwekey_locker_identifier1    = data.aws_ssm_parameter.kms_dummy_val.value # Example, map correctly
    kms_google_pay_root_signing_keys = data.aws_ssm_parameter.kms_google_pay_root_signing_keys.value
    kms_paze_private_key             = data.aws_ssm_parameter.kms_paze_private_key.value
    kms_paze_private_key_passphrase  = data.aws_ssm_parameter.kms_paze_private_key_passphrase.value
    kms_user_auth_encryption_key     = data.aws_ssm_parameter.kms_dummy_val.value # Placeholder
  })]
  depends_on = [helm_release.aws_lb_controller, null_resource.trigger_eks_kms_encryption_lambda, aws_cloudfront_distribution.sdk_distribution]
}

# --- Hyperswitch Web Helm Chart ---
resource "helm_release" "hyperswitch_web" {
  name       = "hypers-web-v1"
  repository = "https://juspay.github.io/hyperswitch-helm/"
  chart      = "hyperswitch-web"
  namespace  = "hyperswitch" # version = "x.y.z"
  values = [templatefile("${path.module}/helm_values/hyperswitch-web-values.yaml.tpl", {
    lb_security_group_id  = aws_security_group.eks_lb_sg.id
    sdk_cloudfront_domain = aws_cloudfront_distribution.sdk_distribution[0].domain_name
    sdk_version           = var.sdk_version_for_helm
    # publishable_key      = "..." # Needs to be sourced, e.g. after merchant creation by SDK demo script
    # secret_key           = "..."
  })]
  depends_on = [helm_release.aws_lb_controller, aws_cloudfront_distribution.sdk_distribution]
}

# --- Istio Traffic Control Helm Chart ---
resource "helm_release" "hyperswitch_istio_traffic_control" {
  name       = "hs-istio"
  repository = "https://juspay.github.io/hyperswitch-helm/charts/incubator/hyperswitch-istio"
  chart      = "hyperswitch-istio" # version = var.hyperswitch_istio_chart_version
  values = [templatefile("${path.module}/helm_values/hyperswitch-istio-values.yaml.tpl", {
    lb_security_group_id = aws_security_group.eks_lb_sg.id
    internal_lb_subnets  = join(",", var.service_layer_zone_subnet_ids)
  })]
  depends_on = [helm_release.istio_ingress_gateway, helm_release.hyperswitch_services]
}

# --- Loki Stack Helm Chart ---
resource "helm_release" "loki_stack" {
  name               = "loki"
  repository         = "https://grafana.github.io/helm-charts/"
  chart              = "loki-stack"
  version            = var.loki_stack_chart_version
  namespace          = "loki"
  create_namespace   = true
  values = [templatefile("${path.module}/helm_values/loki-stack-values.yaml.tpl", {
    private_ecr_prefix        = var.private_ecr_repository_prefix
    grafana_sa_role_arn       = var.grafana_loki_sa_role_arn
    grafana_lb_sg_id          = aws_security_group.grafana_ingress_lb_sg.id
    grafana_lb_public_subnets = join(",", var.external_incoming_zone_subnet_ids)
    loki_s3_bucket_name       = var.loki_s3_bucket_name
    aws_region                = var.aws_region
  })]
  depends_on = [helm_release.hyperswitch_services, aws_iam_openid_connect_provider.this, null_resource.invoke_ecr_image_transfer_build_trigger]
}

# --- WAF ---
resource "aws_wafv2_web_acl" "this" {
  count       = var.waf_arn_for_envoy_alb == null ? 1 : 0
  name        = "${var.stack_prefix}-MainWAF"
  scope       = "REGIONAL"
  description = "Main WAF"
  default_action {
    allow {}
  }
  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsCommonRules"
      sampled_requests_enabled   = true
    }
  }
  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.stack_prefix}MainWAF"
    sampled_requests_enabled   = true
  }
  tags = var.tags
}

# --- Envoy Proxy (Conditional) ---
resource "aws_lb" "envoy_external_alb" {
  count              = var.envoy_ami_id != null ? 1 : 0
  name               = "${var.stack_prefix}-external-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.eks_lb_sg.id]
  subnets            = var.external_incoming_zone_subnet_ids
  tags               = var.tags
}
resource "aws_wafv2_web_acl_association" "envoy_alb_waf_assoc" {
  count        = var.envoy_ami_id != null ? 1 : 0
  resource_arn = aws_lb.envoy_external_alb[0].arn
  web_acl_arn  = var.waf_arn_for_envoy_alb != null ? var.waf_arn_for_envoy_alb : aws_wafv2_web_acl.this[0].arn
  depends_on   = [aws_lb.envoy_external_alb, aws_wafv2_web_acl.this]
}

data "aws_iam_instance_profile" "envoy_profile" {
  count = var.envoy_ami_id != null ? 1 : 0
  name  = module.iam.envoy_ec2_instance_profile_name # Assuming IAM module output
}

data "template_file" "envoy_userdata" {
  count    = var.envoy_ami_id != null ? 1 : 0
  template = file("${path.module}/templates/envoy_userdata.sh.tpl")
  vars = {
    bucket_name = var.proxy_config_s3_bucket_name
  }
}

resource "aws_launch_template" "envoy_lt" {
  count         = var.envoy_ami_id != null ? 1 : 0
  name_prefix   = "${var.stack_prefix}-envoy-"
  image_id      = var.envoy_ami_id
  instance_type = "t3.medium" # Matches CDK
  user_data     = base64encode(data.template_file.envoy_userdata[0].rendered)
  # key_name = "hyperswitch-envoy-keypair" # CDK creates this, ensure it exists or create it

  iam_instance_profile {
    name = data.aws_iam_instance_profile.envoy_profile[0].name
  }

  network_interfaces {
    associate_public_ip_address = true # In external-incoming-zone
    security_groups             = [aws_security_group.eks_lb_sg.id] # Reusing, or a dedicated SG
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.stack_prefix}-envoy-proxy" })
  }
  tags = var.tags
}

resource "aws_autoscaling_group" "envoy_asg" {
  count                     = var.envoy_ami_id != null ? 1 : 0
  name_prefix               = "${var.stack_prefix}-envoy-asg-"
  desired_capacity          = 1 # Matches CDK
  max_size                  = 1 # Matches CDK
  min_size                  = 1 # Matches CDK
  health_check_type         = "ELB"
  health_check_grace_period = 300
  vpc_zone_identifier       = var.external_incoming_zone_subnet_ids

  launch_template {
    id      = aws_launch_template.envoy_lt[0].id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.stack_prefix}-envoy-proxy-asg"
    propagate_at_launch = true
  }
  # for_each = var.tags # This was incorrect, should be dynamic block or separate tags
  # tag { key = each.key, value = each.value, propagate_at_launch = true}
  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  # Target group attachment will be done via aws_autoscaling_attachment or aws_lb_target_group_attachment
}

resource "aws_lb_target_group" "envoy_tg" {
  count       = var.envoy_ami_id != null ? 1 : 0
  name_prefix = "${var.stack_prefix}-envoy-"
  port        = 80 # Port Envoy listens on (e.g. 10000, mapped to 80 on host by userdata)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path     = "/health" # Assuming Envoy has a /health endpoint on its listening port
    protocol = "HTTP"
    port     = "traffic-port"
  }
  tags = var.tags
}

resource "aws_lb_listener" "envoy_alb_listener" {
  count             = var.envoy_ami_id != null ? 1 : 0
  load_balancer_arn = aws_lb.envoy_external_alb[0].arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.envoy_tg[0].arn
  }
}

resource "aws_autoscaling_attachment" "envoy_asg_attachment" {
  count                  = var.envoy_ami_id != null ? 1 : 0
  autoscaling_group_name = aws_autoscaling_group.envoy_asg[0].id
  lb_target_group_arn    = aws_lb_target_group.envoy_tg[0].arn
}


# --- Squid Proxy (Conditional) ---
resource "aws_lb" "squid_internal_alb" {
  count              = var.squid_ami_id != null ? 1 : 0
  name               = "${var.stack_prefix}-outgoing-proxy"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.eks_lb_sg.id]
  subnets            = var.service_layer_zone_subnet_ids
  tags               = var.tags
}

data "aws_iam_instance_profile" "squid_profile" {
  count = var.squid_ami_id != null ? 1 : 0
  name  = module.iam.squid_ec2_instance_profile_name # Assuming IAM module output
}

data "template_file" "squid_userdata" {
  count    = var.squid_ami_id != null ? 1 : 0
  template = file("${path.module}/templates/squid_userdata.sh.tpl")
  vars = {
    bucket_name = var.proxy_config_s3_bucket_name # Squid configs are also in proxy_config_bucket
  }
}

resource "aws_launch_template" "squid_lt" {
  count         = var.squid_ami_id != null ? 1 : 0
  name_prefix   = "${var.stack_prefix}-squid-"
  image_id      = var.squid_ami_id
  instance_type = "t3.medium" # Matches CDK
  user_data     = base64encode(data.template_file.squid_userdata[0].rendered)
  # key_name = "hyperswitch-squid-keypair" # CDK creates this

  iam_instance_profile {
    name = data.aws_iam_instance_profile.squid_profile[0].name
  }
  network_interfaces {
    # associate_public_ip_address = false # In private outgoing-proxy-zone
    security_groups = [aws_security_group.eks_lb_sg.id] # Reusing, or a dedicated SG
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.stack_prefix}-squid-proxy" })
  }
  tags = var.tags
}

resource "aws_autoscaling_group" "squid_asg" {
  count                     = var.squid_ami_id != null ? 1 : 0
  name_prefix               = "${var.stack_prefix}-squid-asg-"
  desired_capacity          = 2 # Matches CDK
  max_size                  = 10 # Matches CDK
  min_size                  = 2 # Matches CDK
  health_check_type         = "ELB"
  health_check_grace_period = 300
  vpc_zone_identifier       = var.outgoing_proxy_zone_subnet_ids # Specific zone for Squid

  launch_template {
    id      = aws_launch_template.squid_lt[0].id
    version = "$Latest"
  }
  tag {
    key                 = "Name"
    value               = "${var.stack_prefix}-squid-proxy-asg"
    propagate_at_launch = true
  }
  # for_each = var.tags # This was incorrect, should be dynamic block or separate tags
  # tag { key = each.key, value = each.value, propagate_at_launch = true}
  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }
}

resource "aws_lb_target_group" "squid_tg" {
  count       = var.squid_ami_id != null ? 1 : 0
  name_prefix = "${var.stack_prefix}-squid-"
  port        = 80 # Port Squid listens on (e.g. 3128, mapped to 80 by userdata/health check setup)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"
  health_check {
    path     = "/health" # Assuming Squid has a /health endpoint or a simple page
    protocol = "HTTP"
    port     = "traffic-port" # Or a specific health check port if configured
  }
  tags = var.tags
}

resource "aws_lb_listener" "squid_alb_listener" {
  count             = var.squid_ami_id != null ? 1 : 0
  load_balancer_arn = aws_lb.squid_internal_alb[0].arn
  port              = 80 # ALB listens on 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.squid_tg[0].arn
  }
}

resource "aws_autoscaling_attachment" "squid_asg_attachment" {
  count                  = var.squid_ami_id != null ? 1 : 0
  autoscaling_group_name = aws_autoscaling_group.squid_asg[0].id
  lb_target_group_arn    = aws_lb_target_group.squid_tg[0].arn
}

# --- Keymanager (Conditional) ---
# module "keymanager" {
#   count = var.keymanager_enabled_in_eks ? 1 : 0
#   source = "./keymanager" # Assuming a sub-module for keymanager
#   # Pass necessary variables: vpc_id, subnet_ids, cluster_name (for helm if deployed in-cluster),
#   # iam_role_for_sa, kms_key_arn, db_config, tls_certs etc.
#   # This is a placeholder for a significant piece of work.
# }
