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

variable "template_id" {
  type    = number
  default = 9001
}

variable "vm_id" {
  type    = number
  default = 400
}

variable "vm_name" {
  type    = string
  default = "rocky9"
}

variable "vm_ip" {
  type    = string
  default = "192.168.1.20/24"
}

variable "gateway" {
  type    = string
  default = "192.168.1.1"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4096
}

variable "disk_size" {
  type    = number
  default = 32
}
