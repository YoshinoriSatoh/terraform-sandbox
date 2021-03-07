resource "aws_db_parameter_group" "default" {
  name   = "${local.infra_fullname}-${var.db_instance.dbname}"
  family = "mysql8.0"

  parameter {
    name  = "explicit_defaults_for_timestamp"
    value = "0"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "character_set_client"
    value = "utf8mb4"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "character_set_connection"
    value = "utf8mb4"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "character_set_database"
    value = "utf8mb4"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "character_set_filesystem"
    value = "utf8mb4"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "character_set_results"
    value = "utf8mb4"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "character_set_server"
    value = "utf8mb4"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "collation_connection"
    value = "utf8mb4_general_ci"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "collation_server"
    value = "utf8mb4_general_ci"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "default_collation_for_utf8mb4"
    value = "utf8mb4_general_ci"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "log_bin_trust_function_creators"
    value = "1"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "log_output"
    value = "FILE"
    apply_method = "pending-reboot" 
  }
  parameter {
    name  = "slow_query_log"
    value = "1"
    apply_method = "pending-reboot" 
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.infra_fullname
    }
  )
}

resource "aws_db_option_group" "default" {
  name   = "${local.infra_fullname}-${var.db_instance.dbname}"
  option_group_description = "Terraform Option Group"
  engine_name              = "mysql"
  major_engine_version     = "8.0"

  tags = merge(
    local.common_tags,
    {
      Name = local.infra_fullname
    }
  )
}

resource "aws_db_subnet_group" "default" {
  name       = "${local.infra_fullname}-${var.db_instance.dbname}"
  subnet_ids = var.private_subnet_ids

  tags = merge(
    local.common_tags,
    {
      Name = local.infra_fullname
    }
  )
}

resource "aws_security_group" "default" {
  name        = var.db_instance.dbname
  description = "${local.infra_fullname}-${var.db_instance.dbname} security group"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    local.common_tags,
    {
      Name = local.infra_fullname
    }
  )
}

resource "aws_security_group_rule" "ingresses" {
  for_each = {
    for key, id in var.allowed_security_group_ids : key => id
  }
  type              = "ingress"
  from_port         = 3306
  to_port           = 3306
  protocol          = "tcp"
  source_security_group_id = each.value
  security_group_id = aws_security_group.default.id
}

resource "aws_db_instance" "default" {
  name                                = var.db_instance.dbname
  engine                              = "mysql"
  engine_version                      = var.db_instance.engine_version
  multi_az                            = var.db_instance.multi_az
  parameter_group_name                = aws_db_parameter_group.default.name
  option_group_name                   = aws_db_option_group.default.name
  db_subnet_group_name                = aws_db_subnet_group.default.name
  instance_class                      = var.db_instance.instance_class
  identifier                          = "${local.infra_fullname}-${var.db_instance.dbname}"
  storage_type                        = var.db_instance.storage_type
  allocated_storage                   = var.db_instance.allocated_storage
  max_allocated_storage               = var.db_instance.max_allocated_storage
  allow_major_version_upgrade         = var.db_instance.allow_major_version_upgrade
  auto_minor_version_upgrade          = var.db_instance.auto_minor_version_upgrade
  port                                = var.db_instance.port
  vpc_security_group_ids              = [aws_security_group.default.id]
  publicly_accessible                 = var.db_instance.publicly_accessible 
  username                            = var.db_instance.username
  password                            = aws_ssm_parameter.rds_password.value 
  iam_database_authentication_enabled = var.db_instance.iam_database_authentication_enabled
  performance_insights_enabled        = var.db_instance.performance_insights_enabled
  delete_automated_backups            = var.db_instance.delete_automated_backups
  deletion_protection                 = var.db_instance.deletion_protection
  backup_retention_period             = var.db_instance.backup_retention_period
  backup_window                       = var.db_instance.backup_window
  maintenance_window                  = var.db_instance.maintenance_window
  enabled_cloudwatch_logs_exports     = var.db_instance.enabled_cloudwatch_logs_exports

  final_snapshot_identifier = "${local.infra_fullname}-${formatdate("YYYY-mm-DD", timestamp())}"

  tags = merge(
    local.common_tags,
    {
      Name = local.infra_fullname
    }
  )
}

resource "random_password" "password" {
  length = 16
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_ssm_parameter" "rds_password" {
  name   = "/${var.infra.name}/${var.infra.env}/rds/core/password"
  type   = "SecureString"
  key_id = var.kms_key_id
  value  = random_password.password.result
}

# Cloudwatch Metric Alerms
resource "aws_cloudwatch_metric_alarm" "cpu_utilization_too_high" {
  alarm_name          = "${local.infra_fullname}_rds_${aws_db_instance.default.name}_cpu_utilization_too_high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_threshold.cpu_utilization
  alarm_description   = "Average database CPU utilization over last 5 minutes too high"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.default.id
  }
}

resource "aws_cloudwatch_metric_alarm" "free_storage_space_too_low" {
  alarm_name          = "${local.infra_fullname}_rds_${aws_db_instance.default.name}_free_storage_space_threshold"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeStorageSpace"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_threshold.free_storage_space
  alarm_description   = "Average database free storage space over last 5 minutes too low"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.default.id
  }
}

resource "aws_cloudwatch_metric_alarm" "freeable_memory_too_low" {
  alarm_name          = "${local.infra_fullname}_rds_${aws_db_instance.default.name}_freeable_memory_too_low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "FreeableMemory"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = var.alarm_threshold.freeable_memory
  alarm_description   = "Average database freeable memory over last 5 minutes too low, performance may suffer"
  alarm_actions       = [var.sns_topic_arn]
  ok_actions          = [var.sns_topic_arn]

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.default.id
  }
}
