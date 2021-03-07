data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_ecs_task_definition" "default" {
  task_definition = local.fullname
}

resource "aws_ecs_service" "default" {
  name            = local.service_fullname
  cluster         = var.ecs_cluster.arn
  task_definition = "${local.fullname}:${data.aws_ecs_task_definition.default.revision}"
  desired_count   = 1

  launch_type = "FARGATE"
  # platform 1.4.0 には未対応 (VPCエンドポイントを設定する必要あり)
  platform_version = "1.3.0"
  propagate_tags = "SERVICE"

  health_check_grace_period_seconds = 120

  # ordered_placement_strategy {
  #   type  = "binpack"
  #   field = "cpu"
  # }

  deployment_controller {
    type = "ECS"
  }

  lifecycle {
    ignore_changes = [
      desired_count,
      task_definition,
      load_balancer,
      platform_version,
    ]
  }

  network_configuration {
    subnets = var.private_subnet.ids
    security_groups = [aws_security_group.ecs_service.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.container.name
    container_port   = var.container.port
  }

  service_registries {
    registry_arn = aws_service_discovery_service.api-core.arn
  }
}

resource "aws_cloudwatch_log_group" "default" {	
  name = "/aws/ecs/${local.fullname}"

  tags = merge(	
    local.common_tags,	
    {}	
  )	
}

resource "aws_security_group" "ecs_service" {
  name        = local.fullname
  description = local.fullname
  vpc_id      = var.vpc.id

  ingress {
    description = "from alb"
    from_port   = var.container.port
    to_port     = var.container.port
    protocol    = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  ingress {
    description = "from private subnet"
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = var.private_subnet.cidr_blocks
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
      Name = local.fullname
    }
  )
}

## Task Role
resource "aws_iam_role" "task-role" {
  name = "${local.fullname}-task-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${local.fullname}-task-role"
    }
  )
}

# Task Policyが必要になったらここに記述
# resource "aws_iam_policy" "task-policy" {
#   name        = "${local.fullname}-policy"
#   description = "${local.fullname} policy"

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": [
#       ],
#       "Effect": "Allow",
#       "Resource": "*"
#     }
#   ]
# }
# EOF
# }

# resource "aws_iam_role_policy_attachment" "task-policy-attach" {
#   role       = aws_iam_role.task-role.name
#   policy_arn = aws_iam_policy.task-policy.arn
# }

## Task Ececution Role
resource "aws_iam_role" "task-execution-role" {
  name = "${local.fullname}-task-execution-role"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

  tags = merge(
    local.common_tags,
    {
      Name = "${local.fullname}-task-execution-role"
    }
  )
}

resource "aws_iam_role_policy_attachment" "AmazonECSTaskExecutionRolePolicy" {
  role       = aws_iam_role.task-execution-role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "task-execution-policy" {
  name        = "${local.fullname}-execution-policy"
  description = "${local.fullname} execution policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "ssm:GetParameters",
        "kms:Decrypt"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:${var.ssm_parameter_prefix}",
        "arn:aws:kms:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:key:${var.kms_key_id}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task-execution-policy-attach" {
  role       = aws_iam_role.task-execution-role.name
  policy_arn = aws_iam_policy.task-execution-policy.arn
}

resource "aws_service_discovery_service" "api-core" {
  name = "api-core"

  dns_config {
    namespace_id = var.service_discovery.private_dns_namespace_id

    dns_records {
      ttl  = 5 
      type = "A"
    }

    routing_policy = "WEIGHTED"
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# Cloudwatch Metric Alerms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_too_high" {
  alarm_name          = "${local.infra_fullname}_${local.service_fullname}_cpu_utilization_too_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_threshold.cpu_utilization
  alarm_description   = "Average database CPU utilization too high"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    ClusterName = var.ecs_cluster.name
    ServiceName = local.service_fullname
  }
}

resource "aws_cloudwatch_metric_alarm" "memory_utilization_too_high" {
  alarm_name          = "${local.infra_fullname}_${local.service_fullname}_memory_utilization_too_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "MemoryUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_threshold.memory_utilization
  alarm_description   = "Average database Memory utilization too high"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    ClusterName = var.ecs_cluster.name
    ServiceName = local.service_fullname
  }
}
