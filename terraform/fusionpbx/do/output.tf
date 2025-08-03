output "fusionpbx" {
  value = "${digitalocean_droplet.fusionpbx.*.ipv4_address}"
}
