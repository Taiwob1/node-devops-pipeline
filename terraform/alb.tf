




# Route 53 Hosted Zone (DNS management)
resource "aws_route53_zone" "main" {
  name = "mydevopsapp.live"
}

# Route 53 Record pointing to ALB
resource "aws_route53_record" "app_record" {
  zone_id = aws_route53_zone.main.zone_id
  name    = "mydevopsapp.live"
  type    = "A"

  alias {
    name                   = aws_lb.app_lb.dns_name
    zone_id                = aws_lb.app_lb.zone_id
    evaluate_target_health = true
  }
}

##############################
# 4️⃣ ACM Certificate (DNS Validation)
##############################

resource "aws_acm_certificate" "my_cert" {
  domain_name       = "mydevopsapp.live"
  validation_method = "DNS"
  subject_alternative_names = [
    "*.mydevopsapp.live"
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.my_cert.domain_validation_options : dvo.domain_name => dvo
  }

  zone_id = aws_route53_zone.main.zone_id
  name    = each.value.resource_record_name
  type    = each.value.resource_record_type
  ttl     = 60
  records = [each.value.resource_record_value]
}

resource "aws_acm_certificate_validation" "my_cert_validation" {
  certificate_arn         = aws_acm_certificate.my_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
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
  certificate_arn = aws_acm_certificate.my_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.node_tg.arn
  }
}
