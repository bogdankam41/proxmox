terraform {
  required_version = ">= 1.6"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.66.1"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "proxmox" {
  endpoint = "https://192.168.1.10:8006/"
  # API-token auth: proxmox_user holds "user@realm!tokenid", proxmox_password holds the token secret.
  api_token = "${var.proxmox_user}=${var.proxmox_password}"
  insecure  = true # self-signed Proxmox certificate on the LAN

  # bpg/proxmox uses SSH to the node for some node-level operations.
  ssh {
    username    = "root"
    private_key = file(pathexpand(var.ssh_key_path))
  }
}
