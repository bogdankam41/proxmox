output "container_id" {
  description = "VMID of the AdGuard Home container."
  value       = proxmox_virtual_environment_container.adguard_home.vm_id
}

output "container_ip" {
  description = "IPv4 address of the AdGuard Home container."
  value       = var.container_ip
}

output "adguard_web_interface" {
  description = "URL of the AdGuard Home web UI."
  value       = "http://${var.container_ip}"
}
