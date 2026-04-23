terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.1"
    }
  }
}

provider "proxmox" {
  endpoint  = "https://192.168.2.10:8006/"
  username  = var.proxmox_user
  password  = var.proxmox_password
  insecure  = true
}