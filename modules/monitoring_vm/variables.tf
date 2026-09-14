# --- Placement ------------------------------------------------------------

variable "proxmox_node" {
  type        = string
  description = "Name of the Proxmox node the VM is created on (e.g. pve, pve-2)."
}

variable "vm_name" {
  type        = string
  description = "VM name / hostname of the monitoring host."
  default     = "monitoring"
}

variable "vm_id" {
  type        = number
  description = "VMID of the monitoring VM."
}

variable "tags" {
  type        = list(string)
  description = "Proxmox tags put on the VM."
  default     = ["monitoring"]
}

# --- Network --------------------------------------------------------------

variable "vm_ip" {
  type        = string
  description = "Static IPv4 address of the VM (must be outside the DHCP pool)."
}

variable "network_cidr" {
  type        = number
  description = "CIDR prefix length of the LAN the VM sits on."
  default     = 24
}

variable "gateway_ip" {
  type        = string
  description = "Default gateway for the VM."
}

variable "dns_servers" {
  type        = list(string)
  description = "DNS servers pushed via cloud-init. Defaults to the gateway (the router), which resolves reliably right after boot."
  default     = null
}

variable "network_bridge" {
  type        = string
  description = "Proxmox bridge the VM NIC is attached to."
  default     = "vmbr0"
}

variable "mac_address" {
  type        = string
  description = "Pinned MAC address — a new random MAC lands in the router's restricted profile with no internet, which breaks the install. Reserve it on the router."
  default     = null
}

# --- Hardware -------------------------------------------------------------

variable "cpu_cores" {
  type        = number
  description = "vCPU cores."
  default     = 2
}

variable "cpu_type" {
  type        = string
  description = "QEMU CPU model. 'host' gives best performance on a single, non-clustered node."
  default     = "host"
}

variable "memory_mb" {
  type        = number
  description = "RAM in MiB. Prometheus + Grafana are comfortable at 2 GiB for a homelab-sized TSDB."
  default     = 2048
}

variable "disk_size" {
  type        = number
  description = "Root disk size in GiB. Holds the Prometheus TSDB, so size it together with prometheus_retention_time."
  default     = 32
}

variable "disk_datastore" {
  type        = string
  description = "Datastore for the root disk and the cloud-init drive."
  default     = "local-lvm"
}

# --- Image ----------------------------------------------------------------

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

variable "download_image" {
  type        = bool
  description = "Manage (download) the cloud image from this state. Set to false when another environment on the same node already manages the same file, so this state only consumes it."
  default     = true
}

# --- Access ---------------------------------------------------------------

variable "vm_username" {
  type        = string
  description = "Cloud-init user created on the VM; Ansible connects as this user and uses sudo."
  default     = "ubuntu"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "Public SSH keys injected into the cloud-init user."
}

variable "ssh_key_path" {
  type        = string
  description = "Path to the PRIVATE SSH key used by Terraform/Ansible to reach the VM."
}

variable "qemu_agent_enabled" {
  type        = bool
  description = "Report VM state via qemu-guest-agent. Keep false for the first apply — the agent is installed by Ansible afterwards; enabling it before that makes Terraform wait for an agent that isn't running yet."
  default     = false
}

# --- Monitored devices ----------------------------------------------------

variable "monitoring_targets" {
  description = <<-EOT
    Devices Prometheus scrapes. One entry per device; this is the list you edit
    when something new appears on the network:

      { name = "pve", address = "192.168.1.10:9100" }
      { name = "router", address = "192.168.1.1:9100", job = "network", labels = { site = "home" } }

    job defaults to var.default_scrape_job, labels default to {}. Targets of the
    same job share one file_sd file, so adding a device to an existing job is
    picked up by Prometheus without a restart.
  EOT

  type = list(object({
    name    = string
    address = string
    job     = optional(string)
    labels  = optional(map(string))
  }))
  default = []
}

variable "default_scrape_job" {
  type        = string
  description = "Scrape job used by targets that do not name one — plain node_exporter hosts."
  default     = "node"
}

variable "scrape_interval" {
  type        = string
  description = "How often Prometheus scrapes its targets."
  default     = "15s"
}

variable "external_labels" {
  type        = map(string)
  description = "Labels attached to every series and alert leaving this Prometheus (e.g. { site = \"home\" })."
  default     = {}
}

# --- Versions -------------------------------------------------------------

variable "prometheus_version" {
  type        = string
  description = "Prometheus release to install (without the leading v)."
  default     = "3.5.0"
}

variable "alertmanager_version" {
  type        = string
  description = "Alertmanager release to install (without the leading v)."
  default     = "0.28.1"
}

variable "node_exporter_version" {
  type        = string
  description = "node_exporter release to install (without the leading v)."
  default     = "1.9.1"
}

variable "grafana_version" {
  type        = string
  description = "Grafana package version to pin, e.g. \"11.6.1\". Empty = latest from the Grafana apt repo."
  default     = ""
}

variable "prometheus_retention_time" {
  type        = string
  description = "How long metrics are kept on disk. Together with disk_size this sets the TSDB budget."
  default     = "30d"
}

# --- Alerting -------------------------------------------------------------

variable "alerts_enabled" {
  type        = bool
  description = "Evaluate the built-in alerting rules (instance down, CPU, memory, disk)."
  default     = true
}

variable "alert_thresholds" {
  type        = map(string)
  description = <<-EOT
    Overrides for the alert_* variables of the Ansible role, e.g.
    { alert_disk_threshold = "90", alert_cpu_for = "15m" }.
    Empty = the role defaults (90% CPU/RAM, 85% disk).
  EOT
  default     = {}
}

variable "telegram_bot_token" {
  type        = string
  description = "Telegram bot token for Alertmanager. Empty = alerts are evaluated and visible in the UI but not delivered anywhere."
  default     = ""
  sensitive   = true
}

variable "telegram_chat_id" {
  type        = string
  description = "Telegram chat ID alerts are sent to."
  default     = ""
}

# --- Grafana --------------------------------------------------------------

variable "grafana_port" {
  type        = string
  description = "TCP port the Grafana web UI listens on."
  default     = "3000"
}

variable "grafana_admin_user" {
  type        = string
  description = "Grafana admin login."
  default     = "admin"
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password (plaintext — it is written into grafana.ini)."
  sensitive   = true
}

variable "grafana_dashboards" {
  description = "Dashboards pulled from grafana.com and provisioned into the 'Homelab' folder. gnet_id/revision are the numbers from the dashboard's grafana.com page."
  type = list(object({
    name     = string
    gnet_id  = number
    revision = number
  }))
  default = [
    {
      name     = "node-exporter-full"
      gnet_id  = 1860
      revision = 37
    },
  ]
}
