output "adguard_web_interface" {
  description = "URL of the AdGuard Home web UI on this node."
  value       = module.adguard_home.adguard_web_interface
}

output "container_ip" {
  description = "IPv4 address of the AdGuard Home container."
  value       = module.adguard_home.container_ip
}
