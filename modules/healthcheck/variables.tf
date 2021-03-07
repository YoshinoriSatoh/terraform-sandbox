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

variable "slack" {
  type = object({
    webhook_url = string
    channel = string
    username = string
  })
}

variable "fqdn" {
  type = string
}
