variable "mm_shortname" {
  type    = "string"
  default = "mm01"
}

resource "digitalocean_tag" "mattermost" {
  name = "mattermost"
}


data "template_file" "mm_config" {
  template = "${file("./config.json.tpl")}"
  vars {
    hostname_fqdn = "${var.mm_shortname}.${var.main_domain}"
  }
}


resource "digitalocean_droplet" "mattermost" {
  image = "${var.base_image}"
  name   = "${var.mm_shortname}.${var.main_domain}"
  region = "fra1"
  size   = "s-2vcpu-4gb"
  backups = false
  private_networking = false
  ssh_keys = [
      "${var.ssh_fingerprint}"
    ]
  tags = ["${digitalocean_tag.mattermost.id}"]
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      timeout = "5m"
  }
  provisioner "remote-exec" {
    inline = [
      "mkdir -p /opt/mm",
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
      "sudo setsebool -P container_manage_cgroup 1",
      "sudo curl -L https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose",
      "sudo chmod +x /usr/local/bin/docker-compose",    
      "git clone https://github.com/mashinarius/mattermost-docker.git /opt/mm",
      "mkdir -pv /opt/mm/volumes/app/mattermost/{data,logs,config}",
      "chown -R 2000:2000 /opt/mm/volumes/app/mattermost/"
    ]
  }

  provisioner "file" {
    content      = "${data.template_file.mm_config.rendered}"
    destination = "/opt/mm/volumes/app/mattermost/config/config.json"
  }
}


# Add a record to the domain
resource "digitalocean_record" "mattermost" {
  domain = "${var.main_domain}"
  type   = "A"
  name   = "${var.mm_shortname}"
  value  = "${digitalocean_droplet.mattermost.ipv4_address}"
  ttl = 60
}


resource "null_resource" "deploy_mattermost" {
  depends_on = ["digitalocean_droplet.mattermost", "digitalocean_record.mattermost"]


  provisioner "remote-exec" {
    inline = [
      "cd /opt/mm",
      "docker-compose up -d"
    ]
  }
  connection {
      user = "root"
      type = "ssh"
      private_key = "${file(var.pvt_key)}"
      host = "${digitalocean_droplet.mattermost.ipv4_address}"
      timeout = "15m"
  }
}
