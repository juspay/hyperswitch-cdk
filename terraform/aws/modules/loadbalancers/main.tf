# Hyperswitch Internal ALB (formerly external ALB - now using VPC origins)
resource "aws_lb" "hyperswitch_alb" {
  name               = "${var.stack_name}-hyperswitch-alb"
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.hyperswitch_alb_sg.id]
  subnets            = var.subnet_ids["isolated"]

  enable_deletion_protection = false
  enable_http2               = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-hyperswitch-alb"
  })
}

# Target Group for Envoy
resource "aws_lb_target_group" "envoy_tg" {
  name     = "${var.stack_name}-hyperswitch-envoy-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 30
    path                = "/healthz"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-hyperswitch-envoy-tg"
  })
}

# Hyperswitch ALB Listener
resource "aws_lb_listener" "hyperswitch_alb_listener" {
  load_balancer_arn = aws_lb.hyperswitch_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.envoy_tg.arn
  }
}

# WAF Association
resource "aws_wafv2_web_acl_association" "hyperswitch_alb_waf" {
  resource_arn = aws_lb.hyperswitch_alb.arn
  web_acl_arn  = var.waf_web_acl_arn
}
