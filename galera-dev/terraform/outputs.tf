output "galera_node_ips" {
  description = "Map of Galera dev node names to their IP addresses"
  value = {
    for key, node in var.galera_nodes : node.name => node.ip
  }
}
