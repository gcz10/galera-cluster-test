output "galera_node_ips" {
  description = "Map of Galera node names to their IP addresses"
  value = {
    for key, node in var.galera_nodes : node.name => node.ip
  }
}

output "loadbalancer_ip" {
  description = "IP address of the load balancer VM"
  value       = var.loadbalancer_vm.ip
}

output "monitoring_ip" {
  description = "IP address of the monitoring VM"
  value       = var.monitoring_vm.ip
}
