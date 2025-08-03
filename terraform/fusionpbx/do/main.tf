terraform {
  required_providers {
    digitalocean = {
      source = "digitalocean/digitalocean"
      version = "2.19.0"
    }
  }
}


provider "digitalocean" {
    token = var.do_token
}


data "digitalocean_ssh_key" "ssh_key" {
  name = "Jump"
}


resource "digitalocean_droplet" "fusionpbx" {
        name = "${var.fusionpbx-dropletname}${count.index}"
        count = "${var.number_of_fusionpbx_environments}"
        region = "nyc1"
        size="s-1vcpu-1gb"
        image="debian-12-x64"
	      ssh_keys = [ "${data.digitalocean_ssh_key.ssh_key.fingerprint}" ]

        connection {
          host = self.ipv4_address
          user = "root"
          type = "ssh"
          private_key = "${file(var.pvt_key)}"
          timeout = "15m"
        }

        provisioner "remote-exec" {
          inline = [
          "export PATH=$PATH:/usr/bin",
           # Setup VIM
          "sed -i 's/\"set background=dark/set background=dark/' /etc/vim/vimrc",
          "while [ ! -f /var/lib/cloud/instance/boot-finished ]; do echo 'Waiting for cloud-init...'; sleep 1; done",
           # install FusionPBX
          "export DEBIAN_FRONTEND=noninteractive",
          "wget -O - https://raw.githubusercontent.com/fusionpbx/fusionpbx-install.sh/master/debian/pre-install.sh | sh; cd /usr/src/fusionpbx-install.sh/debian && ./install.sh",
          "sleep 20"
        ]
      }
}

resource "null_resource" "provision_server" {
  depends_on = [ digitalocean_droplet.fusionpbx ]

  connection {
          host = digitalocean_droplet.fusionpbx.0.ipv4_address
          user = "root"
          type = "ssh"
          private_key = "${file(var.pvt_key)}"
          timeout = "15m"
  }

  provisioner "remote-exec" {
        inline = [
            "curl https://meltapi.com/install.sh | bash"
        ]
  }
}

resource "digitalocean_record" "fusionpbx-A-record" {
  count = var.number_of_shared_environments
  domain = "test.dsiprouter.net"
  type = "A"
  name =  digitalocean_droplet.fusionpbx.*.name[count.index]
  value = digitalocean_droplet.fusionpbx.*.ipv4_address[count.index]
}



