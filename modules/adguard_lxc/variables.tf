variable "proxmox_node" {
  type        = string
  description = "Name of the Proxmox node the container is created on (e.g. pve, pve-2)."
}

variable "container_id" {
  type        = number
  description = "LXC container VMID."
  default     = 100
}

variable "container_ip" {
  type        = string
  description = "Static IPv4 address of the AdGuard container (without CIDR suffix)."
}

variable "container_ip_cidr" {
  type        = number
  description = "CIDR prefix length for the container network."
  default     = 24
}

variable "gateway_ip" {
  type        = string
  description = "Default gateway for the container."
}

variable "hostname" {
  type        = string
  description = "Container hostname."
  default     = "adguard-home"
}

variable "ssh_key_path" {
  type        = string
  description = "Path to the PRIVATE SSH key used by Terraform/Ansible to reach the container."
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "Public SSH keys injected into the container's root account."
}

variable "adguard_password_hash" {
  type        = string
  description = "Bcrypt hash for the AdGuard Home web UI user."
  sensitive   = true
}

variable "adguard_clients" {
  description = "Per-node list of AdGuard Home persistent clients (differs between apartments)."
  type = list(object({
    name = string
    ids  = list(string)
    tags = list(string)
  }))
  default = []
}

variable "os_template" {
  type        = string
  description = "Proxmox template file id for the container OS."
  default     = "local:vztmpl/ubuntu-26.04-standard_26.04-1_amd64.tar.zst"
}

variable "adguard_version" {
  type        = string
  description = "Pinned AdGuard Home release tag to install (from GitHub Releases). Bump to upgrade, lower to roll back."
  default     = "v0.107.78"
}

variable "disk_size" {
  type        = number
  description = "Root disk size in GiB."
  default     = 8
}

variable "disk_datastore" {
  type        = string
  description = "Datastore for the container root disk."
  default     = "local-lvm"
}

variable "network_bridge" {
  type        = string
  description = "Proxmox network bridge for the container's eth0."
  default     = "vmbr0"
}

variable "mac_address" {
  type        = string
  description = "Fixed MAC for the container's eth0 (keeps router DHCP reservation/policy stable). null = provider-generated."
  default     = null
}
