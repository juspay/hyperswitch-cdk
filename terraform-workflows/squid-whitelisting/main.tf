terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Download, process, and upload whitelist
resource "null_resource" "process_whitelist" {
  count = length(var.new_domains) > 0 ? 1 : 0

  triggers = {
    domains_hash = sha256(jsonencode(var.new_domains))
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/process_whitelist.sh"
    environment = {
      S3_BUCKET = var.s3_bucket
      S3_KEY = var.s3_key
      NEW_DOMAINS = join(",", var.new_domains)
    }
  }
}

