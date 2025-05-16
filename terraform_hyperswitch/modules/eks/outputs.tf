output "cluster_id" {
  description = "The ID of the EKS cluster."
  value       = aws_eks_cluster.this.id
}

output "cluster_arn" {
  description = "The ARN of the EKS cluster."
  value       = aws_eks_cluster.this.arn
}

output "cluster_endpoint" {
  description = "The endpoint for the EKS cluster's Kubernetes API server."
  value       = aws_eks_cluster.this.endpoint
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster."
  value       = aws_eks_cluster.this.certificate_authority[0].data # Accessing the first element of the list
}

output "oidc_provider_arn" {
  description = "The ARN of the OIDC Identity Provider."
  value       = aws_iam_openid_connect_provider.this.arn
}

output "oidc_provider_url" {
  description = "The URL of the OIDC Identity Provider."
  value       = aws_iam_openid_connect_provider.this.url
}

output "cluster_security_group_id" {
  description = "The security group ID for the EKS cluster."
  value       = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
}

output "nodegroup_arns" {
  description = "ARNs of the created EKS nodegroups."
  value       = { for k, ng in aws_eks_node_group.this : k => ng.arn }
}

output "nodegroup_ids" {
  description = "IDs of the created EKS nodegroups."
  value       = { for k, ng in aws_eks_node_group.this : k => ng.id }
}

output "sdk_cloudfront_distribution_domain_name" {
  description = "Domain name of the CloudFront distribution for SDK assets."
  value       = aws_cloudfront_distribution.sdk_distribution[0].domain_name
  depends_on  = [aws_cloudfront_distribution.sdk_distribution]
}

output "hyperswitch_app_load_balancer_dns_name" {
  description = "DNS name of the Load Balancer for the Hyperswitch application (from Istio ingress or Hyperswitch-Web ingress)."
  # This will depend on how the Ingress controller provisions the ALB.
  # It might be an output from a helm_release or kubernetes_ingress resource.
  # Placeholder for now.
  value = "To be determined from Ingress/Service status"
}

output "control_center_load_balancer_dns_name" {
  description = "DNS name of the Load Balancer for the Control Center (if separate from app LB)."
  value       = "To be determined from Ingress/Service status"
}

output "grafana_load_balancer_dns_name" {
  description = "DNS name of the Load Balancer for Grafana (from Loki stack Helm chart)."
  value       = "To be determined from Ingress/Service status of Grafana"
}

output "envoy_external_alb_dns_name" {
  description = "DNS name of the external ALB for Envoy (if deployed)."
  value       = aws_lb.envoy_external_alb[0].dns_name
  depends_on  = [aws_lb.envoy_external_alb]
}

output "squid_internal_alb_dns_name" {
  description = "DNS name of the internal ALB for Squid (if deployed)."
  value       = aws_lb.squid_internal_alb[0].dns_name
  depends_on  = [aws_lb.squid_internal_alb]
}
