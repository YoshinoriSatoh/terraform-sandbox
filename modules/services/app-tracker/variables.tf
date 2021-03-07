variable "infra" {
  type = object({
    name = string
    shortname = string
    env  = string
  })
}

variable "service" {
  type = object({
    name = string
    shortname = string
    env  = string
  })
}

locals {
  infra_fullname   = "${var.infra.name}-${var.infra.env}"
  infra_shortname   = "${var.infra.shortname}-${var.infra.env}"
  service_fullname = var.service.env == null ? var.service.name : "${var.service.name}-${var.service.env}"
  service_shortname = var.service.env == null ? var.service.name : "${var.service.shortname}-${var.service.env}"
}

locals {
  fullname = "${local.infra_fullname}-${local.service_fullname}"
  shortname = "${local.infra_shortname}-${local.service_shortname}"
  common_tags = {
    Infra   = local.infra_fullname
    Service = local.service_fullname
  }
}

variable "vpc" {
  type = object({
    id = string
  })
}

variable "private_subnet" {
  type = object({
    ids = list(string)
    cidr_blocks = list(string)
  })
}

variable "alb_security_group_id" {
  type = string 
}

variable "target_group_arn" {
  type = string 
}

variable "ecs_cluster" {
  type = object({
    arn = string
    name = string
  })
}

variable "container" {
  type = object({
    name = string
    port = number
  })
}

variable "alarm_threshold" {
  type = object({
    cpu_utilization = string
    memory_utilization = string
  })
}

variable "sns_topic_arn" {
  type = string
}
