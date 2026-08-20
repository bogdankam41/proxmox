variable "proxmox_node" {
  type        = string
  description = "Name of the Proxmox node the VMs are created on (e.g. pve, pve-2)."
}

variable "cluster_name" {
  type        = string
  description = "Logical cluster name; used for VM tags and the generated inventory file name."
  default     = "k3s"
}

variable "master" {
  description = "The single k3s server (control-plane) node."
  type = object({
    name        = string
    vm_id       = number
    ip          = string
    mac_address = optional(string)
  })
}

variable "workers" {
  description = "k3s agent (worker) nodes."
  type = list(object({
    name        = string
    vm_id       = number
    ip          = string
    mac_address = optional(string)
  }))
  default = []
}

variable "network_cidr" {
  type        = number
  description = "CIDR prefix length of the LAN the VMs sit on."
  default     = 24
}

variable "gateway_ip" {
  type        = string
  description = "Default gateway for the VMs."
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers pushed via cloud-init. Defaults to the gateway (the router), which is the reliable resolver here."
  default     = null
}

variable "network_bridge" {
  type        = string
  description = "Proxmox bridge the VM NICs are attached to."
  default     = "vmbr0"
}

variable "cpu_cores" {
  type        = number
  description = "vCPU cores per VM."
  default     = 2
}

variable "cpu_type" {
  type        = string
  description = "QEMU CPU model. 'host' gives best performance on a single, non-clustered node."
  default     = "host"
}

variable "memory_mb" {
  type        = number
  description = "RAM per VM in MiB."
  default     = 2048
}

variable "disk_size" {
  type        = number
  description = "Root disk size per VM in GiB."
  default     = 20
}

variable "disk_datastore" {
  type        = string
  description = "Datastore for VM root disks and cloud-init drives."
  default     = "local-lvm"
}

variable "image_datastore" {
  type        = string
  description = "Datastore that stores the downloaded cloud image (must accept 'iso' content)."
  default     = "local"
}

variable "image_url" {
  type        = string
  description = "URL of the Ubuntu cloud image used as the VM template disk."
  default     = "https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
}

variable "image_file_name" {
  type        = string
  description = "File name the cloud image is stored under on the Proxmox datastore (must end in .img or .iso)."
  default     = "noble-server-cloudimg-amd64.img"
}

variable "vm_username" {
  type        = string
  description = "Cloud-init user created on every VM; Ansible connects as this user and uses sudo."
  default     = "ubuntu"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "Public SSH keys injected into the cloud-init user."
}

variable "ssh_key_path" {
  type        = string
  description = "Path to the PRIVATE SSH key used by Terraform/Ansible to reach the VMs."
}

variable "qemu_agent_enabled" {
  type        = bool
  description = "Report VM state via qemu-guest-agent. Keep false for the first apply — the agent is installed by Ansible afterwards; enabling it before that makes Terraform wait for an agent that isn't running yet."
  default     = false
}

variable "k3s_channel" {
  type        = string
  description = "k3s release channel used when k3s_version is empty (stable, latest, v1.31, ...)."
  default     = "stable"
}

variable "k3s_version" {
  type        = string
  description = "Exact k3s version to pin, e.g. 'v1.31.5+k3s1'. Empty = follow k3s_channel."
  default     = ""
}

variable "k3s_server_args" {
  type        = list(string)
  description = "Extra arguments for the k3s server (e.g. [\"--disable\", \"traefik\"])."
  default     = []
}

variable "k3s_agent_args" {
  type        = list(string)
  description = "Extra arguments for k3s agents."
  default     = []
}

variable "kubeconfig_local_path" {
  type        = string
  description = "Where the cluster kubeconfig is written on the machine running Terraform. Empty = do not fetch it."
  default     = "~/.kube/homelab-k3s"
}
