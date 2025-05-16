terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Specify a compatible version
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.10" # Check for latest compatible version
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20" # Check for latest compatible version
    }
  }
  required_version = ">= 1.0" # Specify minimum Terraform version
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile # Optional: if using a specific AWS CLI profile
  # shared_credentials_files = ["~/.aws/credentials"] # If using shared credentials
  # access_key = var.aws_access_key # Not recommended for production
  # secret_key = var.aws_secret_key # Not recommended for production
}

# Helm provider configuration - will be configured to point to EKS cluster
provider "helm" {
  kubernetes {
    host                   = local.is_hyperswitch_deployment && !var.free_tier_deployment && length(module.eks) > 0 ? module.eks[0].cluster_endpoint : null
    cluster_ca_certificate = local.is_hyperswitch_deployment && !var.free_tier_deployment && length(module.eks) > 0 ? base64decode(module.eks[0].cluster_certificate_authority_data) : null
    token                  = local.is_hyperswitch_deployment && !var.free_tier_deployment && length(data.aws_eks_cluster_auth.this) > 0 ? data.aws_eks_cluster_auth.this[0].token : null
    # exec { # Alternative for EKS authentication
    #   api_version = "client.authentication.k8s.io/v1beta1"
    #   args        = ["eks", "get-token", "--cluster-name", module.eks[0].cluster_id]
    #   command     = "aws"
    # }
  }
}

# Kubernetes provider configuration - similar to Helm
provider "kubernetes" {
  host                   = local.is_hyperswitch_deployment && !var.free_tier_deployment && length(module.eks) > 0 ? module.eks[0].cluster_endpoint : null
  cluster_ca_certificate = local.is_hyperswitch_deployment && !var.free_tier_deployment && length(module.eks) > 0 ? base64decode(module.eks[0].cluster_certificate_authority_data) : null
  token                  = local.is_hyperswitch_deployment && !var.free_tier_deployment && length(data.aws_eks_cluster_auth.this) > 0 ? data.aws_eks_cluster_auth.this[0].token : null
  # exec {
  #   api_version = "client.authentication.k8s.io/v1beta1"
  #   args        = ["eks", "get-token", "--cluster-name", module.eks[0].cluster_id]
  #   command     = "aws"
  # }
}

# Note: The Helm and Kubernetes providers are conditionally configured.
# If EKS is not deployed (e.g., free_tier_deployment is true), these providers
# will not be initialized with cluster-specific details, which is fine as
# Helm charts and Kubernetes resources are only deployed when EKS is active.
# However, Terraform might still try to initialize them.
# Using 'null' for configuration arguments when EKS is not deployed helps.
