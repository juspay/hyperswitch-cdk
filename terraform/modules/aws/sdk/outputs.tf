output "sdk_distribution_domain_name" {
  value       = aws_cloudfront_distribution.sdk_distribution.domain_name
  description = "The domain name of the SDK CloudFront distribution"
}
