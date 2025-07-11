# External ALB
resource "aws_lb" "external_alb" {
  name               = "${var.stack_name}-external-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.external_lb_sg.id]
  subnets            = var.subnet_ids["external_incoming_zone"]

  enable_deletion_protection = false
  enable_http2               = true

  tags = merge(var.common_tags, {
    Name = "${var.stack_name}-external-alb"
  })
}

# Target Group for Envoy
resource "aws_lb_target_group" "envoy_tg" {
  name     = "${var.stack_name}-envoy-tg"
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
    Name = "${var.stack_name}-envoy-tg"
  })
}

# ALB Listener
resource "aws_lb_listener" "external_alb_listener" {
  load_balancer_arn = aws_lb.external_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.envoy_tg.arn
  }
}

# WAF Association
resource "aws_wafv2_web_acl_association" "external_alb_waf" {
  resource_arn = aws_lb.external_alb.arn
  web_acl_arn  = var.waf_web_acl_arn
}
