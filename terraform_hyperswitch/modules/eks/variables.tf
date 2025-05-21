variable "stack_prefix" {
  description = "Prefix for stack resources."
  type        = string
}

variable "aws_region" {
  description = "AWS region for the deployment."
  type        = string
}

variable "aws_account_id" {
  description = "AWS Account ID."
  type        = string
}

variable "tags" {
  description = "A map of tags to assign to resources."
  type        = map(string)
  default     = {}
}

# VPC and Subnet Configuration
variable "vpc_id" {
  description = "ID of the VPC where the EKS cluster will be deployed."
  type        = string
}

variable "eks_control_plane_subnet_ids" {
  description = "List of subnet IDs for the EKS control plane."
  type        = list(string)
}

variable "eks_worker_nodes_one_zone_subnet_ids" {
  description = "List of subnet IDs for the 'eks-worker-nodes-one-zone' nodegroup."
  type        = list(string)
}
variable "utils_zone_subnet_ids" {
  description = "List of subnet IDs for the 'utils-zone' nodegroup."
  type        = list(string)
}
# Add other specific subnet group ID lists as needed by different nodegroups if they vary beyond worker_nodes_one_zone

variable "service_layer_zone_subnet_ids" { # For Istio Ingress ALB
  description = "List of subnet IDs for the 'service-layer-zone' (internal ALBs)."
  type        = list(string)
}
variable "external_incoming_zone_subnet_ids" { # For external ALBs (Grafana, Envoy)
  description = "List of subnet IDs for the 'external-incoming-zone' (public ALBs)."
  type        = list(string)
}


# EKS Cluster Configuration
variable "cluster_name" {
  description = "Name for the EKS cluster."
  type        = string
  default     = "hs-eks-cluster" # From CDK
}

variable "kubernetes_version" {
  description = "Desired Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.32" # From CDK
}

variable "endpoint_private_access" {
  description = "Indicates whether or not the Amazon EKS private API server endpoint is enabled."
  type        = bool
  default     = true # CDK enables PUBLIC_AND_PRIVATE
}

variable "endpoint_public_access" {
  description = "Indicates whether or not the Amazon EKS public API server endpoint is enabled."
  type        = bool
  default     = true # CDK enables PUBLIC_AND_PRIVATE
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks to allow access to the EKS public endpoint. CDK uses vpn_ips."
  type        = list(string)
  default     = ["0.0.0.0/0"] # Default to allow all if not specified, like CDK if vpn_ips is empty
}

variable "cluster_enabled_log_types" {
  description = "A list of the desired control plane logging to enable."
  type        = list(string)
  default     = ["api", "audit", "authenticator", "controllerManager", "scheduler"] # From CDK
}

# IAM Roles from IAM module
variable "eks_cluster_role_arn" {
  description = "ARN of the IAM role for EKS cluster."
  type        = string
}

variable "eks_nodegroup_role_arn" {
  description = "ARN of the IAM role for EKS Node Groups."
  type        = string
}
variable "eks_admin_arns" {
  description = "List of IAM User/Role ARNs to grant EKS cluster admin access (system:masters)."
  type        = list(string)
  default     = []
}
variable "hyperswitch_app_sa_role_arn" {
  description = "ARN of the IAM role for the Hyperswitch application service account."
  type        = string
}
variable "grafana_loki_sa_role_arn" {
  description = "ARN of the IAM role for the Grafana/Loki service account."
  type        = string
}


# EKS Node Groups (multiple, as per CDK)
# Simplified here, can be expanded into a map of objects for more detail
variable "nodegroup_instance_types" {
  description = "Default instance types for EKS nodegroups."
  type        = list(string)
  default     = ["t3.medium"]
}
variable "nodegroup_min_size" {
  description = "Default min size for nodegroups."
  type        = number
  default     = 1
}
variable "nodegroup_max_size" {
  description = "Default max size for nodegroups."
  type        = number
  default     = 3
}
variable "nodegroup_desired_size" {
  description = "Default desired size for nodegroups."
  type        = number
  default     = 2
}
# Specific nodegroup configurations can be added if they differ significantly

# Secrets and KMS
variable "hyperswitch_app_kms_key_arn" {
  description = "ARN of the KMS key for Hyperswitch application secrets."
  type        = string
}
variable "hyperswitch_app_secrets_manager_arn" { # For the KmsDataSecret
  description = "ARN of the Secrets Manager secret containing data for KMS encryption Lambda."
  type        = string
}
variable "lambda_role_arn_for_kms_encryption" {
  description = "ARN of the IAM role for the Lambda that encrypts secrets for EKS."
  type        = string
}
variable "rds_db_password" { # Plain text, will be part of the KmsDataSecret
  description = "Main RDS database password."
  type        = string
  sensitive   = true
}
variable "hyperswitch_master_enc_key" { # Plain text
  description = "Master encryption key for Hyperswitch application."
  type        = string
  sensitive   = true
}
variable "hyperswitch_admin_api_key" { # Plain text
  description = "Admin API key for Hyperswitch application."
  type        = string
  sensitive   = true
}
variable "locker_public_key_pem" { # From Card Vault module or var
  description = "PEM content of the Locker's public key. Required if locker is enabled."
  type        = string
  default     = "locker-key" # Default from CDK if locker not present
  sensitive   = true
}
variable "tenant_private_key_pem" { # From Card Vault module or var
  description = "PEM content of the Tenant's private key for Locker. Required if locker is enabled."
  type        = string
  default     = "locker-key" # Default from CDK if locker not present
  sensitive   = true
}


# Helm Chart Versions and Values
variable "aws_load_balancer_controller_chart_version" {
  description = "Version of the aws-load-balancer-controller Helm chart."
  type        = string
  default     = "1.8.1" # Check for latest compatible, CDK uses "1.8.1" for image tag v2.12.0
}
variable "ebs_csi_driver_chart_version" {
  description = "Version of the aws-ebs-csi-driver Helm chart."
  type        = string
  default     = "2.31.0" # Check for latest compatible, CDK uses image tag v1.41.0
}
variable "istio_base_chart_version" {
  type    = string
  default = "1.25.0" # CDK uses 1.25.0
}
variable "istio_istiod_chart_version" {
  type    = string
  default = "1.25.0"
}
variable "istio_gateway_chart_version" {
  type    = string
  default = "1.25.0"
}

variable "hyperswitch_stack_chart_version" {
  description = "Version of the hyperswitch-stack Helm chart."
  type        = string
  default     = "0.2.2" # From CDK
}
variable "hyperswitch_istio_chart_version" {
  description = "Version of the hyperswitch-istio Helm chart."
  type        = string
  default     = "0.1.0" # Example, check actual chart version used by CDK's "v1o107o0" image
}
variable "loki_stack_chart_version" {
  description = "Version of the loki-stack Helm chart."
  type        = string
  default     = "2.9.10" # Check for latest compatible
}
variable "metrics_server_chart_version" {
  description = "Version of the metrics-server Helm chart."
  type        = string
  default     = "3.12.1" # Check for latest compatible, CDK uses image tag 0.7.2
}

# ECR Image Transfer
variable "enable_ecr_image_transfer" {
  description = "Whether to enable the ECR image transfer using CodeBuild."
  type        = bool
  default     = true # CDK enables this by default for EKS
}
variable "codebuild_ecr_role_arn" {
  description = "ARN of the IAM role for the CodeBuild ECR image transfer project."
  type        = string
  default     = "" # Required if enable_ecr_image_transfer is true
}
variable "lambda_role_arn_for_codebuild_trigger" {
  description = "ARN of the IAM role for the Lambda that triggers CodeBuild."
  type        = string
  default     = "" # Required if enable_ecr_image_transfer is true
}


# SDK Deployment
variable "sdk_s3_bucket_name" {
  description = "Name of the S3 bucket for SDK assets."
  type        = string
}
variable "sdk_s3_bucket_oai_arn" {
  description = "ARN of the Origin Access Identity for the SDK S3 bucket."
  type        = string
}
variable "sdk_version_for_helm" {
  description = "SDK version to configure in Hyperswitch Helm chart."
  type        = string
  default     = "0.109.2" # From CDK
}
variable "sdk_subversion_for_helm" {
  description = "SDK subversion to configure in Hyperswitch Helm chart."
  type        = string
  default     = "v1" # From CDK, though it uses "v0" in sdk_userdata.sh
}


# External Services (RDS, ElastiCache) - ARNs/Endpoints
variable "rds_cluster_endpoint" {
  description = "Endpoint of the main RDS Aurora cluster."
  type        = string
}
variable "rds_cluster_reader_endpoint" {
  description = "Reader endpoint of the main RDS Aurora cluster."
  type        = string
}
variable "elasticache_cluster_address" {
  description = "Address of the ElastiCache Redis cluster."
  type        = string
}

# Keymanager (conditional deployment within EKS)
variable "keymanager_enabled_in_eks" {
  description = "Whether the Keymanager component is enabled within the EKS deployment."
  type        = bool
  default     = false # Corresponds to config.keymanager.enabled in CDK EKS stack
}
variable "keymanager_config_for_eks" {
  description = "Configuration object for Keymanager if enabled in EKS."
  type = object({
    name     = string
    db_user  = string
    db_pass  = string # Sensitive
    tls_key  = string # Sensitive
    tls_cert = string
    ca_cert  = string
  })
  default = null
}

# Envoy and Squid Proxies (conditional based on AMI availability)
variable "envoy_ami_id" {
  description = "AMI ID for Envoy proxy instances. If provided, Envoy proxy will be set up."
  type        = string
  default     = null
}
variable "squid_ami_id" {
  description = "AMI ID for Squid proxy instances. If provided, Squid proxy will be set up."
  type        = string
  default     = null
}
variable "proxy_config_s3_bucket_name" {
  description = "Name of the S3 bucket for proxy configurations (Envoy, Squid)."
  type        = string
  default     = ""
}
variable "squid_logs_s3_bucket_name" {
  description = "Name of the S3 bucket for Squid logs."
  type        = string
  default     = ""
}
variable "waf_arn_for_envoy_alb" {
  description = "ARN of the WAF WebACL to associate with the Envoy external ALB."
  type        = string
  default     = null
}

# Loki S3 Bucket
variable "loki_s3_bucket_name" {
  description = "Name of the S3 bucket for Loki storage."
  type        = string
}

# Docker image repository prefix (private ECR)
variable "private_ecr_repository_prefix" {
  description = "Prefix for private ECR repositories (e.g., '123456789012.dkr.ecr.us-east-1.amazonaws.com')."
  type        = string
}
