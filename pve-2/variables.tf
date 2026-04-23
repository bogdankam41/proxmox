variable "ssh_key_path" {
  type        = string
  description = "Path to ssh key"
  default     = "~/.ssh/private-key-ed25519"
}

variable "adguard_password_hash" {
  type        = string
  description = "Bcrypt hash for AdGuard UI"
  sensitive   = true
}

variable "proxmox_user" {
  type = string
  description = "Use root@pam for mount folder from proxmox node"
}

variable "proxmox_password" {
  type = string
  description = "root password of proxmox node"
  sensitive = true
}

variable "container_ip" {
  type = string
  description = "IP address of Adguard container"
}

variable "adguard_clients" {
  type = list(object({
    name = string
    ids  = list(string)
    tags = list(string)
  }))
}