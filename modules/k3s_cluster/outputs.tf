output "master_ip" {
  description = "IPv4 address of the k3s control-plane node."
  value       = var.master.ip
}

output "worker_ips" {
  description = "IPv4 addresses of the k3s worker nodes."
  value       = [for w in var.workers : w.ip]
}

output "node_ips" {
  description = "Map of node name to IPv4 address."
  value       = { for name, n in local.nodes : name => n.ip }
}

output "kubeconfig_path" {
  description = "Path of the kubeconfig fetched to the machine running Terraform."
  value       = var.kubeconfig_local_path
}

output "kubectl_hint" {
  description = "How to talk to the cluster."
  value       = "export KUBECONFIG=${var.kubeconfig_local_path} && kubectl get nodes -o wide"
}

output "inventory_path" {
  description = "Generated Ansible inventory for this cluster."
  value       = local.inventory_path
}
