variable "infra" {
  type = object({
    name = string
    shortname = string
    env  = string
  })
}

locals {
  infra_fullname  = "${var.infra.name}-${var.infra.env}"
  infra_shortname = "${var.infra.shortname}-${var.infra.env}"
}

locals {
  common_tags = {
    Infra = local.infra_fullname
  }
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "kms_key_id" {
  type = string
}

variable "allowed_security_group_ids" {
  type = list(string)
}

variable "db_instance" {
  type = object({
    instance_class = string
    engine_version = string
    multi_az = bool
    port = number
    dbname = string
    storage_type = string
    allocated_storage = number
    max_allocated_storage = number
    allow_major_version_upgrade = bool
    auto_minor_version_upgrade = bool
    publicly_accessible = bool 
    username = string
    iam_database_authentication_enabled = bool
    performance_insights_enabled = bool
    delete_automated_backups = bool
    deletion_protection = bool
    backup_retention_period = number
    backup_window = string
    maintenance_window = string
    enabled_cloudwatch_logs_exports = list(string)
  })
}

variable "alarm_threshold" {
  type = object({
    cpu_utilization = string
    free_storage_space = string
    freeable_memory = string
  })
}

variable "sns_topic_arn" {
  type = string
}
