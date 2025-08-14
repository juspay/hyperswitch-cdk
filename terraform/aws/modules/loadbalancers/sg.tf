# External Load Balancer Security Group
resource "aws_security_group" "external_lb_sg" {
  name                   = "${var.stack_name}-external-lb-sg"
  description            = "Security group for external-facing load balancer"
  vpc_id                 = var.vpc_id
  revoke_rules_on_delete = true

  # No egress rules here - will be added as specific rules

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-external-lb-sg"
  })
}

resource "aws_vpc_security_group_ingress_rule" "http_from_cloudfront" {
  security_group_id = aws_security_group.external_lb_sg.id
  cidr_ipv4         = "0.0.0.0/0" # In production, use CloudFront prefix list
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP from CloudFront"
}

resource "aws_vpc_security_group_ingress_rule" "https_from_cloudfront" {
  security_group_id = aws_security_group.external_lb_sg.id
  cidr_ipv4         = "0.0.0.0/0" # In production, use CloudFront prefix list
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS from CloudFront"
}

# CloudFront IP Ranges Data Source
data "aws_ip_ranges" "cloudfront" {
  services = ["CLOUDFRONT"]
  regions  = ["GLOBAL"] # CloudFront IPs are global
}
