output "adguard_web_interface" {
  value = "http://${split("/", proxmox_virtual_environment_container.adguard_home.initialization[0].ip_config[0].ipv4[0].address)[0]}"
}