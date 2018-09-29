terraform {
  backend "consul" {
    address = "consul01.mashinarius.com:8500"
    path    = "status/mm-backend-small"
    lock    = false
    scheme  = "http"
  }
}

variable "main_domain" {}
variable "main_email" {}
variable "base_image" {}

variable "ipa_secret" {}
variable "main_realm" {}