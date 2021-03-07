output "security_group_id" {
  value = aws_security_group.alb.id
}

output "target_group_api_core_arn" {
  value = aws_lb_target_group.api-core.arn
}

output "target_group_app_tracker_arn" {
  value = aws_lb_target_group.app-tracker.arn
}