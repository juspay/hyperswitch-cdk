# Security Group for Lambda function
resource "aws_security_group" "lambda" {
  name_prefix            = "${var.stack_name}-docker-to-ecr-lambda-"
  vpc_id                 = var.vpc_id
  description            = "Security group for CodeBuild trigger Lambda function"
  revoke_rules_on_delete = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-docker-to-ecr-lambda-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_egress_rule" "http_outbound" {
  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
  description       = "HTTP outbound"
}

resource "aws_vpc_security_group_egress_rule" "https_outbound" {
  security_group_id = aws_security_group.lambda.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
  description       = "HTTPS outbound"
}
