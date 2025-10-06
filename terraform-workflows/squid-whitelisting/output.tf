# Outputs
output "domains_to_process" {
  description = "List of domains that were processed"
  value = [for domain in var.new_domains : domain]
}

output "s3_location" {
  description = "S3 location of the whitelist file"
  value = "s3://${var.s3_bucket}/${var.s3_key}"
}
