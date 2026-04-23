resource "proxmox_virtual_environment_container" "adguard_home" {
  node_name = var.proxmox_node
  vm_id     = var.container_id
  
  unprivileged = true 

  initialization {
    hostname = "adguard-home"

    ip_config {
      ipv4 {
        address = "${var.container_ip}/24"
        gateway = var.gateway_ip
      }
    }

    user_account {
      keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIID3vCsyvvecstPJJwvlWm7jz6qtIaCwLtF1KPL9ifI3"] 
    }
  }

  network_interface {
    name   = "eth0"
    bridge = "vmbr0"
  }

  features {
    nesting = true
  }

  operating_system {
    template_file_id = "local:vztmpl/ubuntu-25.04-standard_25.04-1.1_amd64.tar.zst"
    type             = "ubuntu"
  }

  disk {
    datastore_id = "local-lvm"
    size         = 8
  }

  mount_point {
    volume = "/var/lib/adguard-data" # path on proxmox
    path   = "/opt/AdGuardHome/data" # path inside container
  }

  provisioner "remote-exec" {
    inline = ["echo SSH is ready"]

    connection {
      type        = "ssh"
      user        = "root"
      private_key = file(var.ssh_key_path)
      host        = var.container_ip
    }
  }

  provisioner "local-exec" {
    command = <<EOT
      export ANSIBLE_HOST_KEY_CHECKING=False
      ansible-playbook -i '${var.container_ip},' \
      --private-key ${var.ssh_key_path} \
      -u root \
      -e '${jsonencode({
      adguard_password_hash = var.adguard_password_hash,
      adguard_clients       = var.adguard_clients,
    })}' \
      ../ansible/playbook.yml
    EOT
  }

  connection {
    type        = "ssh"
    user        = "root"
    private_key = file(var.ssh_key_path)
    host        = var.container_ip
  }
}