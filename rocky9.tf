data "local_file" "ssh_public_key" {
  filename = pathexpand(var.ssh_public_key_path)
}

# --- Cloud-init: vendor config (packages & first-boot commands) ---

resource "proxmox_virtual_environment_file" "cloud_init_vendor" {
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
    # TODO: Add your packages and runcmd commands above.
    EOF

    file_name = "rocky9-vendor-config.yaml"
  }
}

# --- Rocky Linux 9 Template ---

resource "proxmox_virtual_environment_vm" "rocky9_template" {
  name      = "rocky9-template"
  node_name = var.node_name
  vm_id     = var.template_id

  template = true
  started  = false

  cpu {
    cores = var.cores
    type  = "host"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = "local-zfs"
    import_from  = "local:0/rocky9-base.qcow2"
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.disk_size
  }

  network_device {
    bridge = "vmbr0"
    model  = "virtio"
  }

  operating_system {
    type = "l26"
  }

  serial_device {}
}

# --- Rocky Linux 9 VM (cloned from template) ---

resource "proxmox_virtual_environment_vm" "rocky9" {
  name      = var.vm_name
  node_name = var.node_name
  vm_id     = var.vm_id

  clone {
    vm_id = proxmox_virtual_environment_vm.rocky9_template.vm_id
  }

  stop_on_destroy = true

  agent {
    enabled = true
  }

  initialization {
    datastore_id = "local-zfs"

    dns {
      servers = ["8.8.8.8", "1.1.1.1"]
    }

    ip_config {
      ipv4 {
        address = var.vm_ip
        gateway = var.gateway
      }
    }

    user_account {
      username = "rocky"
      keys     = [trimspace(data.local_file.ssh_public_key.content)]
    }

    vendor_data_file_id = proxmox_virtual_environment_file.cloud_init_vendor.id
  }
}
