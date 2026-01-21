output "internal_alb_security_group_id" {
  description = "ID of the Internal Load Balancer Security Group"
  value       = aws_security_group.internal_alb_sg.id
}

output "internal_alb_dns_name" {
  description = "DNS name of the Istio Internal ALB"
  value       = data.aws_lb.internal_alb.dns_name
}
