resource "aws_lb" "public" {
  name               = local.infra_fullname
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.public_subnet.ids
  enable_deletion_protection = false

  access_logs {
    bucket  = aws_s3_bucket.alb_logs.bucket
    prefix  = local.infra_fullname
    enabled = true
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.infra_fullname
    }
  )
}

resource "aws_security_group" "alb" {
  name        = "${local.infra_fullname}-alb"
  description = "${local.infra_fullname} alb"
  vpc_id      = var.vpc.id

  ingress {
    description = "http (for redirect)"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "https production"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-alb"
    }
  )
}

resource "aws_lb_listener" "redirect" {
  load_balancer_arn = aws_lb.public.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.public.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn

  lifecycle {
    ignore_changes = [default_action]
  }

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app-tracker.arn
  }
}

resource "aws_lb_listener_rule" "forward-api-core" {
  listener_arn = aws_lb_listener.listener.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api-core.arn
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
}

resource "aws_lb_target_group" "app-tracker" {
  name        = "${local.infra_fullname}-app-tracker"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc.id
}

resource "aws_lb_target_group" "api-core" {
  name        = "${local.infra_fullname}-api-core"
  port        = 8000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc.id
  health_check {
    path = "/api/health"
    port = 8000
  }
}

# Route53
resource "aws_route53_record" "a-record" {
  zone_id = var.hostedzone_id
  name    = var.host == "" ? var.domain : "${var.host}.${var.domain}"
  type    = "A"

  alias {
    name                   = aws_lb.public.dns_name
    zone_id                = aws_lb.public.zone_id
    evaluate_target_health = true
  }
}

# Access log bucket
resource "aws_s3_bucket" "alb_logs" {
  bucket = "${local.infra_fullname}-alb-logs"
  acl    = "private"

  force_destroy = true

  tags = merge(
    local.common_tags,
    {
      Name = "${local.infra_fullname}-alb-logs"
    }
  )
}
resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::582318560864:root"
      },
      "Action": "s3:PutObject",
      "Resource": "arn:aws:s3:::${aws_s3_bucket.alb_logs.id}/*"
    }
  ]
}
POLICY
}

