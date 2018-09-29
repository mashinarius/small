terraform {
  backend "consul" {
    address = "consul01.mashinarius.com:8500"
    path    = "status/gitlab-backend-small"
    lock    = false
    scheme  = "http"
  }
}

variable "main_domain" {}
variable "main_email" {}
variable "base_image" {}
variable "ldap_secret" {}