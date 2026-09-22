# Environment: pve-k3s — k3s practice cluster on the home Proxmox node (LAN 192.168.1.0/24).
# Separate state from envs/pve so applying or destroying the cluster never touches AdGuard.
module "k3s" {
  source = "../../modules/k3s_cluster"

  proxmox_node = "pve"
  cluster_name = "k3s"

  gateway_ip = "192.168.1.1"
  # AdGuard, now that the cluster is up: node DNS is filtered and shows up in
  # the AdGuard query log. The router was only the bootstrap resolver, needed
  # while AdGuard could not yet be relied on during the first boot.
  dns_servers = ["192.168.1.2"]

  # MACs are pinned: a new random MAC lands in the router's restricted profile
  # with no internet, which breaks the k3s install. Reserve these on the router.
  # The control plane (API server, etcd/sqlite, scheduler) needs the most headroom.
  master = {
    name        = "k3s-master"
    vm_id       = 200
    ip          = "192.168.1.30"
    mac_address = "BC:24:11:A0:30:30"
    memory_mb   = 4096
  }

  workers = [
    {
      name        = "k3s-worker-1"
      vm_id       = 201
      ip          = "192.168.1.31"
      mac_address = "BC:24:11:A0:30:31"
      memory_mb   = 4096
    },
    {
      name        = "k3s-worker-2"
      vm_id       = 202
      ip          = "192.168.1.32"
      mac_address = "BC:24:11:A0:30:32"
      memory_mb   = 4096
    },
  ]

  cpu_cores = 2
  # Fallback for any node that does not set memory_mb itself.
  memory_mb = 2048
  disk_size = 20

  ssh_key_path    = var.ssh_key_path
  ssh_public_keys = var.ssh_public_keys

  # Stock k3s: Traefik + ServiceLB + local-path storage.
  k3s_channel           = var.k3s_channel
  k3s_version           = var.k3s_version
  kubeconfig_local_path = var.kubeconfig_local_path
}
