terraform {
  required_version = "~> 1.12.2"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.46.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.0.2"
    }
    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

module "helm" {
  source                   = "../../modules/helm"
  project_id               = var.project_id
  region                   = var.region
  stack_name               = var.stack_name
  gke_cluster_name         = var.gke_cluster_name
  hyperswitch_namespace    = "hyperswitch"
  app_cdn_domain_name      = "http://localhost:8080"
  sdk_cdn_domain_name      = "http://localhost:9050"
  sdk_version              = "0.125.0"
  enable_external_postgresql = false
  db_primary_host_endpoint = "http://localhost:5432"
  db_reader_host_endpoint  = "http://localhost:5432"
  db_password              = "password"
  enable_external_redis    = false
  redis_host_endpoint      = "http://localhost:6379"
  redis_port               = 6379
}

# module "secrets_manager" {
#   source     = "../../../modules/gcp/secrets_manager"
#   project_id = var.project_id
#   region     = var.region
# }
