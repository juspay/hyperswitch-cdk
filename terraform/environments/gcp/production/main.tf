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
  project     = var.project_id
  region      = var.region
}


