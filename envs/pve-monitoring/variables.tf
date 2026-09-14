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
  description = "Path to the PRIVATE SSH key used to provision the VM and the Proxmox node."
  default     = "~/.ssh/private-key-ed25519"
}

variable "ssh_public_keys" {
  type        = list(string)
  description = "Public SSH keys injected into the cloud-init user on the VM."
  default = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIID3vCsyvvecstPJJwvlWm7jz6qtIaCwLtF1KPL9ifI3"
  ]
}

variable "monitoring_targets" {
  description = <<-EOT
    Devices Prometheus scrapes. Add a device here and run `tofu apply` — no .tf
    file or template needs editing. Each entry:

      name    — label shown in Grafana/alerts
      address — host:port of the exporter (node_exporter listens on 9100)
      job     — optional scrape job; defaults to "node"
      labels  — optional extra labels

    The device itself must expose an exporter; for a plain Linux host run
    ansible/node_exporter.yml against it first.
  EOT

  type = list(object({
    name    = string
    address = string
    job     = optional(string)
    labels  = optional(map(string))
  }))
  default = []
}

variable "prometheus_retention_time" {
  type        = string
  description = "How long metrics are kept on disk."
  default     = "30d"
}

variable "grafana_admin_user" {
  type        = string
  description = "Grafana admin login."
  default     = "admin"
}

variable "grafana_admin_password" {
  type        = string
  description = "Grafana admin password."
  sensitive   = true
}

variable "grafana_dashboards" {
  description = <<-EOT
    Dashboards pulled from grafana.com into the "Homelab" folder. gnet_id and
    revision are the numbers from the dashboard's page on grafana.com
    (https://grafana.com/grafana/dashboards/<gnet_id>). Add an entry and run
    `tofu apply` — the JSON is downloaded and bound to the Prometheus datasource.
  EOT

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

variable "alerts_enabled" {
  type        = bool
  description = "Evaluate the built-in alerting rules (instance down, CPU, memory, disk)."
  default     = true
}

variable "alert_thresholds" {
  type        = map(string)
  description = "Overrides for the role's alert_* variables, e.g. { alert_disk_threshold = \"90\" }."
  default     = {}
}

variable "telegram_bot_token" {
  type        = string
  description = "Telegram bot token for Alertmanager. Empty = alerts stay in the UI only."
  default     = ""
  sensitive   = true
}

variable "telegram_chat_id" {
  type        = string
  description = "Telegram chat ID alerts are sent to."
  default     = ""
}
