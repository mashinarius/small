variable "do_token" {}
variable "pub_key" {}
variable "pvt_key" {}
variable "ssh_fingerprint" {}

provider "digitalocean" {
  token = "${var.do_token}"
}

provider "consul" {
  address    = "consul01.mashinarius.com:8500"
  datacenter = "fra1_small"
}
