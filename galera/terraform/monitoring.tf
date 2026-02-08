resource "proxmox_virtual_environment_file" "cloud_init_monitoring" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.node_name

  source_raw {
    data = <<-EOF
      #cloud-config
      package_update: true
      packages:
        - qemu-guest-agent
      runcmd:
        - systemctl enable --now qemu-guest-agent
    EOF

    file_name = "${var.monitoring_vm.name}-vendor-config.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "monitoring" {
  vm_id     = var.monitoring_vm.vm_id
  name      = var.monitoring_vm.name
  node_name = var.node_name

  clone {
    vm_id = var.template_vm_id
  }

  cpu {
    cores = 2
    type  = "host"
  }

  memory {
    dedicated = 4096
  }

  disk {
    datastore_id = "local-zfs"
    interface    = "virtio0"
    size         = 32
    iothread     = true
    discard      = "on"
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-zfs"

    ip_config {
      ipv4 {
        address = "${var.monitoring_vm.ip}/24"
        gateway = var.gateway
      }
    }

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    user_account {
      keys     = [trimspace(file(pathexpand(var.ssh_public_key_path)))]
      username = "rocky"
    }

    vendor_data_file_id = proxmox_virtual_environment_file.cloud_init_monitoring.id
  }

  agent {
    enabled = true
  }
}
