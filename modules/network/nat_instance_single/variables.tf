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
    cidr_block = string
  })
}

variable "subnets" {
  type = object({
    public = object({
      a = object({
        cidr_block = string
      })
      c = object({
        cidr_block = string
      })
    })
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

variable "nat_instance" {
  type = object({
    ami = string
    instance_type = string
  })
}
