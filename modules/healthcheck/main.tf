data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

module "health_check_notify_slack" {
  source  = "terraform-aws-modules/notify-slack/aws"
  version = "~> 4.0"

  sns_topic_name = "${local.infra_fullname}-health-check-slack-topic"
  lambda_function_name = "${local.infra_fullname}_health_check_notify_slack"

  slack_webhook_url = var.slack.webhook_url
  slack_channel     = var.slack.channel
  slack_username    = var.slack.username
}

resource "aws_cloudwatch_metric_alarm" "api-core-health-check" {
  alarm_name          = "${local.infra_fullname}-api_core_health_check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "HealthCheckStatus"
  namespace = "AWS/Route53"
  period = "60"
  statistic = "Minimum"
  threshold = "1"
  alarm_description = "This metric monitor api-core url healthcheck"
  alarm_actions = [module.health_check_notify_slack.this_slack_topic_arn]
  ok_actions    = [module.health_check_notify_slack.this_slack_topic_arn]
  dimensions = {
    HealthCheckId = aws_route53_health_check.api-core.id
  }
}

resource "aws_route53_health_check" "api-core" {
  fqdn              = var.fqdn
  port              = 443
  type              = "HTTPS"
  resource_path     = "/api/health"
  failure_threshold = "5"
  request_interval  = "30"
  # cloudwatch_alarm_name   = "api_core_health_check"
  # cloudwatch_alarm_region = "${data.aws_region.current.name}"
  # cloudwatch_alarm_region = "us-east-1"

  tags = merge(
    local.common_tags,
    {}
  )
}

resource "aws_cloudwatch_metric_alarm" "app-tracker-health-check" {
  alarm_name          = "${local.infra_fullname}-app_tracker_health_check"
  comparison_operator = "LessThanThreshold"
  evaluation_periods = "1"
  metric_name = "HealthCheckStatus"
  namespace = "AWS/Route53"
  period = "60"
  statistic = "Minimum"
  threshold = "1"
  alarm_description = "This metric monitor app-tracker url healthcheck"
  alarm_actions = [module.health_check_notify_slack.this_slack_topic_arn]
  ok_actions    = [module.health_check_notify_slack.this_slack_topic_arn]
  dimensions = {
    HealthCheckId = aws_route53_health_check.app-tracker.id
  }
}

resource "aws_route53_health_check" "app-tracker" {
  fqdn              = var.fqdn
  port              = 443
  type              = "HTTPS"
  resource_path     = "/"
  failure_threshold = "5"
  request_interval  = "30"
  # cloudwatch_alarm_name   = "app_tracker_health_check"
  # cloudwatch_alarm_region = "${data.aws_region.current.name}"
  # cloudwatch_alarm_region = "us-east-1"

  tags = merge(
    local.common_tags,
    {}
  )
}
