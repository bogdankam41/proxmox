module "adguard_home" {
  source = "../modules/adguard_lxc"
  proxmox_node          = "pve"
  container_id          = 100
  container_ip          = "192.168.1.2"
  gateway_ip            = "192.168.1.1"
  ssh_key_path          = "~/.ssh/private-key-ed25519"
  adguard_password_hash = var.adguard_password_hash
  adguard_clients       = var.adguard_clients
}