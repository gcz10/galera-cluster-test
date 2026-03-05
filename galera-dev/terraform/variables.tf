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
    node1 = { vm_id = 601, ip = "192.168.1.61", name = "galera-dev-1" }
    node2 = { vm_id = 602, ip = "192.168.1.62", name = "galera-dev-2" }
    node3 = { vm_id = 603, ip = "192.168.1.63", name = "galera-dev-3" }
  }
}
