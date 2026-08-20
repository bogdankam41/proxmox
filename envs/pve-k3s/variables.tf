variable "proxmox_user" {
  type        = string
  description = "Proxmox auth user, i.e. \"user@realm!tokenid\" when using an API token."
  default     = "terraform@pve!terraform"
}

variable "proxmox_password" {
  type        = string
  description = "API-token secret (or password) for proxmox_user."
  sensitive   = true
}

variable "ssh_key_path" {
  type        = string
  description = "Path to the PRIVATE SSH key used to provision the VMs and the Proxmox node."
  default     = "~/.ssh/private-key-ed25519"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "Public SSH keys injected into the cloud-init user on every VM."
  default = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIID3vCsyvvecstPJJwvlWm7jz6qtIaCwLtF1KPL9ifI3"
  ]
}

variable "k3s_channel" {
  type        = string
  description = "k3s release channel used when k3s_version is empty."
  default     = "stable"
}

variable "k3s_version" {
  type        = string
  description = "Exact k3s version to pin, e.g. \"v1.31.5+k3s1\". Empty = follow k3s_channel."
  default     = ""
}

variable "kubeconfig_local_path" {
  type        = string
  description = "Where to write the cluster kubeconfig on this machine."
  default     = "~/.kube/homelab-k3s"
}
