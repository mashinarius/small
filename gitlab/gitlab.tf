variable "gitlab_shortname" {
  type    = "string"
  default = "gitlab01"
}

resource "digitalocean_tag" "gitlab" {
  name = "gitlab"
}

# Create VM for Gitlab in DO
resource "digitalocean_droplet" "gitlab" {
  image = "${var.base_image}"
  name   = "${var.gitlab_shortname}.${var.main_domain}"
  region = "fra1"
  size   = "s-2vcpu-4gb"
  backups = false
  private_networking = false
  ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
  tags = ["${digitalocean_tag.gitlab.id}"]
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      timeout = "5m"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo mkdir -p /opt/gitlab/data",
      "sudo mkdir -p /opt/gitlab/config",
      "sudo mkdir -p /opt/gitlab/logs",
      "sudo mkdir /etc/docker"
    ]
  }

  # Copy Docker daemon config
  provisioner "file" {
    source      = "daemon.json"
    destination = "/etc/docker/daemon.json"
  }

  # Install Docker
  provisioner "remote-exec" {
    inline = [
      "sudo yum install -y yum-utils device-mapper-persistent-data lvm2 mc git bind-utils",
      "sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo",
      "sudo yum -y install docker-ce",
      "sudo systemctl start docker",
      "sudo setsebool -P container_manage_cgroup 1"
    ]
  }
}


# Add a record to the domain
resource "digitalocean_record" "gitlab" {
  domain = "${var.main_domain}"
  type   = "A"
  name   = "${var.gitlab_shortname}"
  value  = "${digitalocean_droplet.gitlab.ipv4_address}"
  ttl = 60
}

data "template_file" "gitlab_rb_le" {
  template = "${file("./gitlab.rb.tpl")}"
  vars {
    GL_FQDN = "${var.gitlab_shortname}.${var.main_domain}"
    GL_EMAIL = "${var.main_email}"
  }
}
#IPA_FQDN = "${consul_keys.ipa_status.var.fqdn}"
data "template_file" "gitlab_ldap_yml" {
  template = "${file("./ldap.yml.tpl")}"
  vars {
    IPA_FQDN = "ipa01.mashinarius.com"
    LDAP_SECRET = "${var.ldap_secret}"
  }
}

resource "null_resource" "deploy_gitlab" {
  depends_on = ["digitalocean_droplet.gitlab", "digitalocean_record.gitlab"]

  provisioner "file" {
    content      = "${data.template_file.gitlab_rb_le.rendered}"
    destination = "/opt/gitlab/config/gitlab.rb"
  }

  provisioner "file" {
    content      = "${data.template_file.gitlab_ldap_yml.rendered}"
    destination = "/opt/gitlab/config/ldap.yml"
  }

  # Start Gitlab Docker container
  provisioner "remote-exec" {
    inline = [
      "docker run --detach -h ${var.gitlab_shortname}.${var.main_domain} -p 443:443 -p 80:80 -p 2022:22 --name gitlab --restart always -v /opt/gitlab/config:/etc/gitlab:Z -v /opt/gitlab/logs:/var/log/gitlab:Z -v /opt/gitlab/data:/var/opt/gitlab:Z gitlab/gitlab-ce:latest"
    ]
  }
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      host = "${digitalocean_droplet.gitlab.ipv4_address}"
      timeout = "15m"
  }
}

# Initialize template for consul config
data "template_file" "consul_config" {
  template = "${file("./consul.config.tpl")}"
  vars {
    CONSUL_SERVER = "consul01.mashinarius.com"
    CONSUL_DC = "fra1_small"
    CONSUL_CLIENT_ADDR = "0.0.0.0"
    CONSUL_ENCRYPT = "LM9SolZg09T/zRPZwVYHQw=="
  }
}

# Initialize template for gitlab service
data "template_file" "gitlab_service" {
  template = "${file("./gitlab.service.tpl")}"
  vars {
    GL_FQDN = "${var.gitlab_shortname}.${var.main_domain}"
  }
}


resource "null_resource" "deploy_consul" {
  depends_on = ["null_resource.deploy_gitlab"]

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
    content      = "${data.template_file.gitlab_service.rendered}"
    destination = "/opt/consul/config/gitlab.service.json"
  }

  # Start Consul docker container
  provisioner "remote-exec" {
    inline = [
      "docker run -d --name=consul -v /opt/consul:/consul:Z --net=host consul agent -bind=${digitalocean_droplet.gitlab.ipv4_address} -config-file /consul/config.json -config-dir /consul/config"
    ]
  }

  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      host = "${digitalocean_droplet.gitlab.ipv4_address}"
      timeout = "15m"
  }
}

/*
data "consul_keys" "ipa_status" {
  datacenter = "fra1_small"
  key {
    name    = "fqdn"
    path    = "service/freeipa/fqdn"
    default = ""
  }
}

data "template_file" "gitlab_rb" {
  template = "${file("./gitlab.rb.tpl")}"
  vars {
    GL_FQDN = "${var.gitlab_shortname}.${var.main_domain}"
    GL_EMAIL = "${var.main_email}"
  }
}

data "template_file" "gitlab_ldap_yml" {
  template = "${file("./ldap.yml.tpl")}"
  vars {
    IPA_FQDN = "${consul_keys.ipa_status.var.fqdn}"
  }
}

resource "null_resource" "add_freeipa" {
  depends_on = ["consul_keys.ipa_status"]

  provisioner "file" {
    content      = "${data.template_file.gitlab_rb.rendered}"
    destination = "/opt/gitlab/config/gitlab.rb"
  }

  provisioner "file" {
    content      = "${data.template_file.gitlab_ldap_yml.rendered}"
    destination = "/opt/gitlab/config/ldap.yml"
  }

  provisioner "remote-exec" {
    inline = [
      "docker restart gitlab"
    ]
  }
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      host = "${digitalocean_droplet.gitlab.ipv4_address}"
      timeout = "15m"
  }
}
*/
