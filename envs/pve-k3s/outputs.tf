output "master_ip" {
  description = "IPv4 address of the k3s control-plane node."
  value       = module.k3s.master_ip
}

output "worker_ips" {
  description = "IPv4 addresses of the k3s worker nodes."
  value       = module.k3s.worker_ips
}

output "kubeconfig_path" {
  description = "Kubeconfig fetched to this machine."
  value       = module.k3s.kubeconfig_path
}

output "kubectl_hint" {
  description = "How to talk to the cluster."
  value       = module.k3s.kubectl_hint
}
