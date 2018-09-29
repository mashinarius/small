variable "ipa_shortname" {
  type    = "string"
  default = "ipa01"
}

resource "digitalocean_tag" "freeipa" {
  name = "freeipa"
}

data "template_file" "ipa_install_options" {
  template = "${file("./ipa-server-install-options.tpl")}"
  vars {
    IPA_REALM = "${var.main_realm}"
    IPA_DOMAIN = "${var.main_domain}"
    IPA_SECRET = "${var.ipa_secret}"
  }
}


resource "digitalocean_droplet" "freeipa" {
  image = "${var.base_image}"
  name   = "${var.ipa_shortname}.${var.main_domain}"
  region = "fra1"
  size   = "s-2vcpu-2gb"
  backups = false
  private_networking = false
  ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
  tags = ["${digitalocean_tag.freeipa.id}"]
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      timeout = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir /var/lib/ipa-data",
      "sudo mkdir /etc/docker"
    ]
  }

  provisioner "file" {
    content      = "${data.template_file.ipa_install_options.rendered}"
    destination = "/var/lib/ipa-data/ipa-server-install-options"
  }

  provisioner "file" {
    source      = "daemon.json"
    destination = "/etc/docker/daemon.json"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y yum-utils device-mapper-persistent-data lvm2 mc bind-utils",
      "sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
      "sudo yum -y install docker-ce",
      "sudo systemctl start docker",
      "sudo setsebool -P container_manage_cgroup 1"
    ]
  }

#  output "address" {
#    value = "${var.ipa_shortname}.${var.main_domain}"
#  }
  
}

# Add a record to the domain
resource "digitalocean_record" "ipa" {
  domain = "${var.main_domain}"
  type   = "A"
  name   = "${var.ipa_shortname}"
  value  = "${digitalocean_droplet.freeipa.ipv4_address}"
  ttl = 60
}

resource "null_resource" "deploy_freeipa" {
  depends_on = ["digitalocean_droplet.freeipa", "digitalocean_record.ipa"]
  provisioner "remote-exec" {
    inline = [
      "docker run --name freeipa-server-container -e ADMIN_SECRET=${var.ipa_secret} -h ${var.ipa_shortname}.${var.main_domain} -e IPA_SERVER_IP=0.0.0.0 -p 53:53/udp -p 53:53 -p 80:80 -p 443:443 -p 389:389 -p 636:636 -p 88:88 -p 464:464 -p 88:88/udp -p 464:464/udp -p 123:123/udp -p 7389:7389 -p 9443:9443 -p 9444:9444 -p 9445:9445 -v /sys/fs/cgroup:/sys/fs/cgroup:ro -v /var/lib/ipa-data:/data:Z --tmpfs /run --tmpfs /tmp mashinarius/freeipa-server exit-on-finished",
      "docker start freeipa-server-container"
    ]
  }

  provisioner "local-exec" {
    command = "sleep 120"
  }

    provisioner "remote-exec" {
    inline = [
      "docker exec -ti -e ADMIN_SECRET=${var.ipa_secret} freeipa-server-container sh -c 'cd /opt/ipa-le && /opt/ipa-le/setup-le.sh'"
    ]
  }
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      host = "${digitalocean_droplet.freeipa.ipv4_address}"
      timeout = "15m"
  }
}

data "template_file" "consul_config" {
  template = "${file("./consul.config.tpl")}"
  vars {
    CONSUL_SERVER = "consul01.mashinarius.com"
    CONSUL_DC = "${var.do_region}"
    CONSUL_CLIENT_ADDR = "0.0.0.0"
    CONSUL_ENCRYPT = "${var.consul_encrypt}"
  }
}

# Initialize template for gitlab service
data "template_file" "freeipa_service" {
  template = "${file("./freeipa.service.tpl")}"
  vars {
    IPA_FQDN = "${var.ipa_shortname}.${var.main_domain}"
  }
}

resource "null_resource" "deploy_consul" {
  depends_on = ["null_resource.deploy_freeipa"]

  # Create Dir for Consul configs and data
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /opt/consul/config",
      "mkdir -p /opt/consul/data"
    ]
  }

  # Copy consul agent config from template
  provisioner "file" {
    content      = "${data.template_file.consul_config.rendered}"
    destination = "/opt/consul/config.json"
  }

  # Copy consul service for Gitlab from template
  provisioner "file" {
    content      = "${data.template_file.freeipa_service.rendered}"
    destination = "/opt/consul/config/freeipa.service.json"
  }

  # Start Consul docker container
  provisioner "remote-exec" {
    inline = [
      "docker run -d --name=consul -v /opt/consul:/consul:Z --net=host consul agent -bind=${digitalocean_droplet.freeipa.ipv4_address} -config-file /consul/config.json -config-dir /consul/config"
    ]
  }

  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      host = "${digitalocean_droplet.freeipa.ipv4_address}"
      timeout = "15m"
  }
}

