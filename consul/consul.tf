variable "consul_shortname" {
  type    = "string"
  default = "consul01"
}

resource "digitalocean_tag" "consul" {
  name = "consul"
}

resource "digitalocean_droplet" "consul" {
  image = "${var.base_image}"
  name   = "${var.consul_shortname}.${var.main_domain}"
  region = "fra1"
  size   = "s-1vcpu-1gb"
  backups = false
  private_networking = false
  ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
  tags = ["${digitalocean_tag.consul.id}"]
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      timeout = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p /opt/consul/config",
      "mkdir -p /opt/consul/data",
      "mkdir /etc/docker"
    ]
  }

  provisioner "file" {
    source      = "daemon.json"
    destination = "/etc/docker/daemon.json"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y yum-utils device-mapper-persistent-data lvm2 mc git wget bind-utils",
      "sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
      "sudo yum -y install docker-ce",
      "sudo systemctl start docker",
      "sudo setsebool -P container_manage_cgroup 1"
    ]
  }
}


# Add a record to the domain
resource "digitalocean_record" "consul" {
  domain = "${var.main_domain}"
  type   = "A"
  name   = "${var.consul_shortname}"
  value  = "${digitalocean_droplet.consul.ipv4_address}"
  ttl = 60
}

# Initialize template for consul config
data "template_file" "consul_config" {
  template = "${file("./consul.config.tpl")}"
  vars {
    CONSUL_DC = "fra1_small"
    CONSUL_ENCRYPT = "LM9SolZg09T/zRPZwVYHQw=="
  }
}

resource "null_resource" "deploy_consul" {
  depends_on = ["digitalocean_droplet.consul", "digitalocean_record.consul"]

  # Copy consul agent config from template
  provisioner "file" {
    content      = "${data.template_file.consul_config.rendered}"
    destination = "/opt/consul/config.json"
  }

  provisioner "remote-exec" {
    inline = [
      "docker run -d --name=consul-server -v /opt/consul:/consul:Z --net=host --restart always -e 'CONSUL_ALLOW_PRIVILEGED_PORTS=' consul agent -bind=${digitalocean_droplet.consul.ipv4_address} -client=${digitalocean_droplet.consul.ipv4_address} -config-file /consul/config.json -config-dir /consul/config"
    ]
  }

  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      host = "${digitalocean_droplet.consul.ipv4_address}"
      timeout = "15m"
  }
}

output "consul_server_ui_address" {
   value = "http://${var.consul_shortname}.${var.main_domain}:8500/ui"
}
