output "hyperswitch_cloudfront_distribution_domain_name" {
  value       = module.loadbalancers.hyperswitch_cloudfront_distribution_domain_name
  description = "The domain name of the Hyperswitch CloudFront distribution"
}

output "sdk_distribution_domain_name" {
  value       = module.sdk.sdk_distribution_domain_name
  description = "The domain name of the SDK CloudFront distribution"
}

output "eks_cluster_name" {
  value       = module.eks.eks_cluster_name
  description = "Name of the EKS cluster"
}

output "eks_cluster_endpoint" {
  value       = module.eks.eks_cluster_endpoint
  description = "Endpoint of the EKS cluster"
}

output "rds_cluster_endpoint" {
  value       = module.rds.rds_cluster_endpoint
  description = "RDS cluster writer endpoint"
}

output "rds_cluster_reader_endpoint" {
  value       = module.rds.rds_cluster_reader_endpoint
  description = "RDS cluster reader endpoint"
}

output "elasticache_cluster_endpoint" {
  value       = module.elasticache.elasticache_cluster_endpoint_address
  description = "ElastiCache cluster endpoint"
}

output "internal_alb_dns_name" {
  value       = module.helm.internal_alb_dns_name
  description = "Internal ALB DNS name for Istio"
}

output "squid_nlb_dns_name" {
  value       = module.squid_proxy.squid_nlb_dns_name
  description = "Squid proxy NLB DNS name"
}

output "vpc_id" {
  value       = module.vpc.vpc_id
  description = "VPC ID"
}