output "monitoring_vm_ip" {
  description = "IPv4 address of the monitoring VM."
  value       = module.monitoring.vm_ip
}

output "grafana_url" {
  description = "Grafana web UI."
  value       = module.monitoring.grafana_url
}

output "prometheus_url" {
  description = "Prometheus web UI."
  value       = module.monitoring.prometheus_url
}

output "alertmanager_url" {
  description = "Alertmanager web UI."
  value       = module.monitoring.alertmanager_url
}

output "scrape_targets" {
  description = "Devices Prometheus scrapes, grouped by job."
  value       = module.monitoring.scrape_targets
}
