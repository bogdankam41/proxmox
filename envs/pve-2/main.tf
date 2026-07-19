# Environment: pve-2 — remote Proxmox server at the second apartment (LAN 192.168.2.0/24),
# reachable from pve over the site-to-site IPSec tunnel.
# Node-specific topology lives here; secrets and the client list live in terraform.tfvars.
module "adguard_home" {
  source = "../../modules/adguard_lxc"

  proxmox_node = "pve-2"
  container_id = 100
  container_ip = "192.168.2.2" # home network (trusted); holds the default route
  gateway_ip   = "192.168.2.1"
  mac_address  = "BC:24:11:3C:70:48" # reserved on the router

  # Second NIC: guest network — devices that only need DNS, no home-network access.
  guest_interface = {
    name        = "net-guest"
    ip          = "192.168.3.2"
    cidr        = 24
    bridge      = "vmbr0"
    vlan_id     = 2
    firewall    = true
    mac_address = "BC:24:11:E1:8D:0A"
  }

  ssh_key_path    = var.ssh_key_path
  ssh_public_keys = var.ssh_public_keys

  adguard_password_hash = var.adguard_password_hash
  adguard_clients       = var.adguard_clients
}
