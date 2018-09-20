# Set the variable value in *.tfvars file
# or using -var="do_token=..." CLI option
#variable "do_token" {}

# Configure the DigitalOcean Provider
#provider "digitalocean" {
#  token = "${var.do_token}"
#}

# Create a new tag

resource "digitalocean_tag" "consul" {
  name = "consul"
}

resource "digitalocean_tag" "freeipa" {
  name = "freeipa"
}

resource "digitalocean_tag" "mastermost" {
  name = "mastermost"
}

resource "digitalocean_tag" "gitlab" {
  name = "gitlab"
}

resource "digitalocean_droplet" "sm-server-1" {
  image = "38147840"
  name   = "sm-server-1"
  region = "fra1"
  size   = "s-1vcpu-1gb"
  backups = false
  private_networking = false
  ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
  tags = ["${digitalocean_tag.consul.id}", "${digitalocean_tag.gitlab.id}"]
  user_data = "sudo ufw allow 8300 && sudo ufw allow 8301 && sudo ufw allow 8302 && sudo ufw allow 8400 && sudo ufw allow 8500 && sudo ufw allow 8600"
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      timeout = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ufw allow 8300 && sudo ufw allow 8301 && sudo ufw allow 8302 && sudo ufw allow 8400 && sudo ufw allow 8500 && sudo ufw allow 8600",
      "docker run -d --name=consul-server --net=host -e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' consul agent -server -bind=${self.ipv4_address} -client=${self.ipv4_address} -bootstrap-expect=3 -dns-port=53 -recursor=8.8.8.8 -ui"
    ]
  }
}

resource "digitalocean_droplet" "sm-server-2" {
  image = "38147840"
  name   = "sm-server-2"
  region = "fra1"
  user_data = "sudo ufw allow 8300 && sudo ufw allow 8301 && sudo ufw allow 8302 && sudo ufw allow 8400 && sudo ufw allow 8500 && sudo ufw allow 8600"
  size   = "s-1vcpu-1gb"
  backups = false
  private_networking = false
  ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
  tags = ["${digitalocean_tag.consul.id}", "${digitalocean_tag.freeipa.id}"]

  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      timeout = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ufw allow 8300 && sudo ufw allow 8301 && sudo ufw allow 8302 && sudo ufw allow 8400 && sudo ufw allow 8500 && sudo ufw allow 8600",
      "docker run -d --name=consul-server --net=host -e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' consul agent -server -bind=${self.ipv4_address} -client=${self.ipv4_address} -join=${digitalocean_droplet.sm-server-1.ipv4_address}"
    ]
  }

}

resource "digitalocean_droplet" "sm-server-3" {
  image = "38147840"
  name   = "sm-server-3"
  region = "fra1"
  size   = "s-1vcpu-1gb"
  backups = false
  private_networking = false
  user_data = "sudo ufw allow 8300 && sudo ufw allow 8301 && sudo ufw allow 8302 && sudo ufw allow 8400 && sudo ufw allow 8500 && sudo ufw allow 8600"
  ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
  tags = ["${digitalocean_tag.consul.id}", "${digitalocean_tag.mastermost.id}"]

  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      timeout = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo ufw allow 8300 && sudo ufw allow 8301 && sudo ufw allow 8302 && sudo ufw allow 8400 && sudo ufw allow 8500 && sudo ufw allow 8600", 
      "docker run -d --name=consul-server --net=host -e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' consul agent -server -bind=${self.ipv4_address} -client=${self.ipv4_address} -join=${digitalocean_droplet.sm-server-1.ipv4_address}"
    ]
  }
}

