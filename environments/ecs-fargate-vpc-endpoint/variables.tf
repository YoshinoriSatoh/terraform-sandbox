variable "profile" {
  type = string
}

variable "infra" {
  type = object({
    name = string
    shortname = string
    env  = string
  })
}

locals {
  infra_fullname = "${var.infra.name}-${var.infra.env}"
}

locals {
  common_tags = {
    Infra = local.infra_fullname
  }
}

variable "vpc" {
  type = object({
    cidr_block = string
  })
}

variable "subnets" {
  type = object({
    private = object({
      a = object({
        cidr_block = string
      })
      c = object({
        cidr_block = string
      })
    })
  })
}