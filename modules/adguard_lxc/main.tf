resource "proxmox_virtual_environment_container" "adguard_home" {
  node_name = var.proxmox_node
  vm_id     = var.container_id

  unprivileged = true

  initialization {
    hostname = var.hostname

    ip_config {
      ipv4 {
        address = "${var.container_ip}/${var.container_ip_cidr}"
        gateway = var.gateway_ip
      }
    }

    # Second (guest) NIC ip_config — order must match the network_interface blocks below. No gateway.
    dynamic "ip_config" {
      for_each = var.guest_interface != null ? [var.guest_interface] : []
      content {
        ipv4 {
          address = "${ip_config.value.ip}/${ip_config.value.cidr}"
        }
      }
    }

    user_account {
      keys = var.ssh_public_keys
    }
  }

  network_interface {
    name        = "eth0"
    bridge      = var.network_bridge
    mac_address = var.mac_address # pinned so router MAC-based policy/reservation survives recreation
  }

  dynamic "network_interface" {
    for_each = var.guest_interface != null ? [var.guest_interface] : []
    content {
      name        = network_interface.value.name
      bridge      = network_interface.value.bridge
      vlan_id     = network_interface.value.vlan_id
      firewall    = network_interface.value.firewall
      mac_address = network_interface.value.mac_address
    }
  }

  features {
    nesting = true
  }

  operating_system {
    template_file_id = var.os_template
    type             = "ubuntu"
  }

  disk {
    datastore_id = var.disk_datastore
    size         = var.disk_size
  }
}

# Provisioning is a separate resource so the Ansible run repeats whenever the
# config template, role, client list or password changes — WITHOUT recreating
# the container. Edit the config then `tofu apply` to push it.
resource "terraform_data" "provision" {
  triggers_replace = [
    proxmox_virtual_environment_container.adguard_home.id,
    filesha256("${path.module}/../../ansible/playbook.yml"),
    filesha256("${path.module}/../../ansible/roles/adguard/tasks/main.yml"),
    filesha256("${path.module}/../../ansible/roles/adguard/handlers/main.yml"),
    filesha256("${path.module}/../../ansible/roles/adguard/templates/AdGuardHome.yaml.j2"),
    jsonencode(var.adguard_clients),
    var.adguard_password_hash,
    var.adguard_version,
  ]

  # Wait until the container is reachable over SSH before running Ansible.
  provisioner "remote-exec" {
    inline = ["echo SSH is ready"]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(pathexpand(var.ssh_key_path))
      host        = var.container_ip
    }
  }

  # Configure AdGuard Home via the shared Ansible role. The playbook path is
  # resolved relative to this module, so it works from any environment under envs/.
  provisioner "local-exec" {
    command = <<-EOT
      export ANSIBLE_HOST_KEY_CHECKING=False
      ansible-playbook -i '${var.container_ip},' \
        --private-key ${var.ssh_key_path} \
        -u root \
        -e '${jsonencode({
    adguard_password_hash = var.adguard_password_hash
    adguard_clients       = var.adguard_clients
    bootstrap_dns         = var.gateway_ip
    adguard_version       = var.adguard_version
})}' \
        ${path.module}/../../ansible/playbook.yml
    EOT
}
}

