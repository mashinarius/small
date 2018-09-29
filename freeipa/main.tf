terraform {
  backend "consul" {
    address = "consul01.mashinarius.com:8500"
    path    = "status/ipa-backend-small"
    lock    = false
    scheme  = "http"
  }
}

variable "main_domain" {}
variable "main_email" {}
variable "base_image" {}

variable "ipa_secret" {}
variable "main_realm" {}

variable "consul_encrypt" {}

variable "do_region" {}

