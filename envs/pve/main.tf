# Environment: pve — home Proxmox server (LAN 192.168.1.0/24).
# Node-specific topology lives here; secrets and the client list live in terraform.tfvars.
module "adguard_home" {
  source = "../../modules/adguard_lxc"

  proxmox_node = "pve"
  container_id = 100
  container_ip = "192.168.1.2"
  gateway_ip   = "192.168.1.1"
  mac_address  = "BC:24:11:E8:47:2F" # reserved on the router (static lease + internet policy)

  ssh_key_path    = var.ssh_key_path
  ssh_public_keys = var.ssh_public_keys

  adguard_password_hash = var.adguard_password_hash
  adguard_clients       = var.adguard_clients
}
