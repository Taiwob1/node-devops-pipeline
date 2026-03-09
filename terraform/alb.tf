# ACM Certificate
resource "aws_acm_certificate" "app_cert" {
  domain_name       = "yourdomain.com"
  validation_method = "DNS"
}

# ALB
resource "aws_lb" "app_lb" {
  name               = "node-devops-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.app_sg.id]
  subnets            = [aws_subnet.public.id]
}

# Target Group
resource "aws_lb_target_group" "node_tg" {
  name        = "node-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.main.id

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200"
  }
}

# HTTP Listener (Port 80)
resource "aws_lb_listener" "node_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.node_tg.arn
  }
}

# HTTPS Listener (Port 443)
resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = 443
  protocol          = "HTTPS"

  ssl_policy      = "ELBSecurityPolicy-2016-08"
  certificate_arn = aws_acm_certificate.app_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.node_tg.arn
  }
}
# Route 53 Hosted Zone (DNS management)
resource "aws_route53_zone" "main" {
  name = "mydevopsapp.com"
}

# Route 53 Record pointing to ALB
resource "aws_route53_record" "app_record" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "api.mydevopsapp.com"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}
