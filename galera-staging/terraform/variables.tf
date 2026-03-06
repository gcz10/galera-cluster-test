variable "proxmox_endpoint" {
  type    = string
  default = "https://192.168.1.177:8006/"
}

variable "proxmox_api_token" {
  type      = string
  sensitive = true
}

variable "node_name" {
  type    = string
  default = "pve"
}

variable "template_vm_id" {
  type    = number
  default = 9001
}

variable "gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "galera_nodes" {
  type = map(object({
    vm_id = number
    ip    = string
    name  = string
  }))
  default = {
    node1 = { vm_id = 701, ip = "192.168.1.71", name = "galera-staging-1" }
    node2 = { vm_id = 702, ip = "192.168.1.72", name = "galera-staging-2" }
    node3 = { vm_id = 703, ip = "192.168.1.73", name = "galera-staging-3" }
  }
}
