output "template_id" {
  description = "Proxmox template VM ID"
  value       = proxmox_virtual_environment_vm.rocky9_template.vm_id
}

output "vm_id" {
  description = "Proxmox VM ID"
  value       = proxmox_virtual_environment_vm.rocky9.vm_id
}

output "vm_ip" {
  description = "IP address of the Rocky Linux 9 VM"
  value       = var.vm_ip
}
