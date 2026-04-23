variable "proxmox_node" {}
variable "container_id" {}
variable "container_ip" {}
variable "gateway_ip" {}
variable "ssh_key_path" {}
variable "adguard_password_hash" {}
variable "adguard_clients" {
  description = "List of clients for AdGuard Home"
  type = list(object({
    name = string
    ids  = list(string)
    tags = list(string)
  }))
  default = []
}