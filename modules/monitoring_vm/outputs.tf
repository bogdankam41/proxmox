output "vm_id" {
  description = "VMID of the monitoring VM."
  value       = proxmox_virtual_environment_vm.monitoring.vm_id
}

output "vm_ip" {
  description = "IPv4 address of the monitoring VM."
  value       = var.vm_ip
}

output "grafana_url" {
  description = "Grafana web UI."
  value       = "http://${var.vm_ip}:${var.grafana_port}"
}

output "prometheus_url" {
  description = "Prometheus web UI."
  value       = "http://${var.vm_ip}:9090"
}

output "alertmanager_url" {
  description = "Alertmanager web UI."
  value       = "http://${var.vm_ip}:9093"
}

output "scrape_targets" {
  description = "Devices Prometheus scrapes, grouped by job."
  value = {
    for job in distinct([for t in var.monitoring_targets : coalesce(t.job, var.default_scrape_job)]) :
    job => [for t in var.monitoring_targets : t.address if coalesce(t.job, var.default_scrape_job) == job]
  }
}
