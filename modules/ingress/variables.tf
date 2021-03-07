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

variable "vpc" {
  type = object({
    id = string
  })
}

variable "public_subnet" {
  type = object({
    ids = list(string)
    cidr_blocks = list(string)
  })
}

variable "hostedzone_id" {
  type = string
}

variable "domain" {
  type = string
}

variable "host" {
  type = string
}

variable "certificate_arn" {
  type = string
}
