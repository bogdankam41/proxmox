# A single QEMU VM running the homelab monitoring stack:
# Prometheus + Alertmanager + Grafana + node_exporter.
# Terraform creates the VM from an Ubuntu cloud image; Ansible installs the stack.

locals {
  dns_servers = var.dns_servers != null ? var.dns_servers : [var.gateway_ip]

  ansible_dir = "${path.module}/../../ansible"
  private_key = pathexpand(var.ssh_key_path)

  # Re-run Ansible whenever the playbook or any role file changes,
  # without recreating the VM.
  ansible_files = sort(concat(
    [for f in fileset(local.ansible_dir, "monitoring.yml") : f],
    [for f in fileset(local.ansible_dir, "roles/monitoring/**") : f],
    [for f in fileset(local.ansible_dir, "roles/node_exporter/**") : f],
  ))
  ansible_fingerprint = sha256(join("", [for f in local.ansible_files : filesha256("${local.ansible_dir}/${f}")]))

  # Everything the monitoring role reads. Target defaults (job, labels) are
  # filled in by the role, so tfvars entries can stay short.
  ansible_extra_vars = merge(
    {
      monitoring_targets     = var.monitoring_targets
      monitoring_default_job = var.default_scrape_job
      monitoring_self_name   = var.vm_name

      prometheus_version         = var.prometheus_version
      prometheus_retention_time  = var.prometheus_retention_time
      prometheus_scrape_interval = var.scrape_interval
      prometheus_external_labels = var.external_labels

      alertmanager_version            = var.alertmanager_version
      node_exporter_version           = var.node_exporter_version
      monitoring_alerts_enabled       = var.alerts_enabled
      alertmanager_telegram_bot_token = var.telegram_bot_token
      alertmanager_telegram_chat_id   = var.telegram_chat_id

      grafana_version        = var.grafana_version
      grafana_listen_port    = var.grafana_port
      grafana_admin_user     = var.grafana_admin_user
      grafana_admin_password = var.grafana_admin_password
      grafana_dashboards     = var.grafana_dashboards
    },
    var.alert_thresholds,
  )
}

# Ubuntu cloud image on the node. Shared with other environments that use the
# same file name — overwrite = false means an existing file is reused, not re-downloaded.
resource "proxmox_virtual_environment_download_file" "cloud_image" {
  count = var.download_image ? 1 : 0

  content_type = "iso"
  datastore_id = var.image_datastore
  node_name    = var.proxmox_node
  url          = var.image_url
  file_name    = var.image_file_name
  overwrite    = false
}

resource "proxmox_virtual_environment_vm" "monitoring" {
  name        = var.vm_name
  description = "Monitoring stack: Prometheus + Alertmanager + Grafana (managed by Terraform)"
  tags        = var.tags

  node_name = var.proxmox_node
  vm_id     = var.vm_id

  on_boot         = true
  stop_on_destroy = true

  # Enabled only after Ansible has installed qemu-guest-agent — otherwise
  # Terraform waits for an agent that does not answer yet.
  agent {
    enabled = var.qemu_agent_enabled
  }

  cpu {
    cores = var.cpu_cores
    type  = var.cpu_type
  }

  memory {
    dedicated = var.memory_mb
  }

  disk {
    datastore_id = var.disk_datastore
    file_id      = var.download_image ? proxmox_virtual_environment_download_file.cloud_image[0].id : "${var.image_datastore}:iso/${var.image_file_name}"
    interface    = "scsi0"
    size         = var.disk_size
    discard      = "on"
    ssd          = true
  }

  initialization {
    datastore_id = var.disk_datastore

    ip_config {
      ipv4 {
        address = "${var.vm_ip}/${var.network_cidr}"
        gateway = var.gateway_ip
      }
    }

    dns {
      servers = local.dns_servers
    }

    user_account {
      username = var.vm_username
      keys     = var.ssh_public_keys
    }
  }

  network_device {
    bridge = var.network_bridge
    # Pinned so the router's DHCP reservation / internet policy survives a recreate.
    mac_address = var.mac_address
  }

  operating_system {
    type = "l26"
  }

  # Cloud images expect a serial console.
  serial_device {}
}

# Wait until cloud-init has finished before Ansible touches the VM.
resource "terraform_data" "wait_for_cloud_init" {
  triggers_replace = [proxmox_virtual_environment_vm.monitoring.id]

  provisioner "remote-exec" {
    inline = [
      "cloud-init status --wait || true",
      "echo '${var.vm_name} is ready'",
    ]

    connection {
      type        = "ssh"
      user        = var.vm_username
      private_key = file(local.private_key)
      host        = var.vm_ip
      timeout     = "10m"
    }
  }
}

# Configuration is a separate resource, so editing the role, the device list or
# a version re-runs Ansible WITHOUT recreating the VM.
resource "terraform_data" "provision" {
  depends_on = [terraform_data.wait_for_cloud_init]

  triggers_replace = [
    proxmox_virtual_environment_vm.monitoring.id,
    local.ansible_fingerprint,
    jsonencode(local.ansible_extra_vars),
  ]

  provisioner "local-exec" {
    command = <<-EOT
      export ANSIBLE_HOST_KEY_CHECKING=False
      ansible-playbook -i '${var.vm_ip},' \
        --private-key ${var.ssh_key_path} \
        -u ${var.vm_username} \
        --become \
        -e '${jsonencode(local.ansible_extra_vars)}' \
        ${local.ansible_dir}/monitoring.yml
    EOT
  }
}
