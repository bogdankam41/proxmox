# Environment: pve-2 — remote Proxmox server at the second apartment (LAN 192.168.2.0/24),
# reachable from pve over the site-to-site IPSec tunnel.
# Node-specific topology lives here; secrets and the client list live in terraform.tfvars.
module "adguard_home" {
  source = "../../modules/adguard_lxc"

  proxmox_node = "pve-2"
  container_id = 100
  container_ip = "192.168.2.2"
  gateway_ip   = "192.168.2.1"

  ssh_key_path    = var.ssh_key_path
  ssh_public_keys = var.ssh_public_keys

  adguard_password_hash = var.adguard_password_hash
  adguard_clients       = var.adguard_clients
}
