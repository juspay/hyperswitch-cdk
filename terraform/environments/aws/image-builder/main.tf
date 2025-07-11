terraform {
  required_version = ">= 0.12"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider configurations
provider "aws" {
  region = var.aws_region
}

# Data sources for existing resources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}


locals {
  # VPC CIDR configuration
  vpc_cidr = var.vpc_cidr

  # Availability zones
  azs = slice(data.aws_availability_zones.available.names, 0, var.az_count)

}

module "image_builder" {
  source     = "../../../modules/aws/image-builder"
  stack_name = var.stack_name
  vpc_cidr   = local.vpc_cidr
  az_count   = var.az_count

  # Pass any additional variables required by the module
  # ami_id     = var.ami_id

}
