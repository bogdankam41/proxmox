# Environment: pve-monitoring — Prometheus + Alertmanager + Grafana on the home
# Proxmox node (LAN 192.168.1.0/24). Separate state from envs/pve and envs/pve-k3s,
# so applying or destroying monitoring never touches AdGuard or the cluster.
module "monitoring" {
  source = "../../modules/monitoring_vm"

  proxmox_node = "pve"
  vm_name      = "monitoring"
  vm_id        = 210
  vm_ip        = "192.168.1.40"
  gateway_ip   = "192.168.1.1"
  # MAC is pinned: a new random MAC lands in the router's restricted profile
  # with no internet, which breaks the install. Reserve it on the router.
  mac_address = "BC:24:11:A0:30:40"
  # The router resolves reliably right after boot; AdGuard (192.168.1.2) can be
  # put first here once everything is up.
  dns_servers = ["192.168.1.2"]

  cpu_cores = 2
  memory_mb = 2048
  # TSDB lives on this disk — keep it in step with prometheus_retention_time.
  disk_size = 32

  # envs/pve-k3s already downloads this exact cloud image onto the node; this
  # state just consumes the file instead of managing it a second time.
  download_image = false

  ssh_key_path    = var.ssh_key_path
  ssh_public_keys = var.ssh_public_keys

  # Devices to scrape — the list to edit when something new appears on the LAN.
  monitoring_targets = var.monitoring_targets
  external_labels    = { site = "home" }

  prometheus_retention_time = var.prometheus_retention_time

  grafana_admin_user     = var.grafana_admin_user
  grafana_admin_password = var.grafana_admin_password
  grafana_dashboards     = var.grafana_dashboards

  alerts_enabled     = var.alerts_enabled
  alert_thresholds   = var.alert_thresholds
  telegram_bot_token = var.telegram_bot_token
  telegram_chat_id   = var.telegram_chat_id
}
