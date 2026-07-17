variable "proxmox_user" {
  type        = string
  description = "Proxmox auth user. root@pam is required to bind-mount host folders into the container."
  default     = "root@pam"
}

variable "proxmox_password" {
  type        = string
  description = "Password (or API-token secret) for proxmox_user. See README for the API-token alternative."
  sensitive   = true
}

variable "ssh_key_path" {
  type        = string
  description = "Path to the PRIVATE SSH key used to provision the container."
  default     = "~/.ssh/private-key-ed25519"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "Public SSH keys injected into the container's root account."
  default = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIID3vCsyvvecstPJJwvlWm7jz6qtIaCwLtF1KPL9ifI3"
  ]
}

variable "adguard_password_hash" {
  type        = string
  description = "Bcrypt hash for the AdGuard Home web UI."
  sensitive   = true
}

variable "adguard_clients" {
  description = "Per-node list of AdGuard Home persistent clients."
  type = list(object({
    name = string
    ids  = list(string)
    tags = list(string)
  }))
  default = []
}
