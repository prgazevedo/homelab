# This file contains Terraform configurations for existing VMs that will be imported
# These configurations are generated based on the current state discovered from Proxmox

# VM 101: W11-VM (Windows 11)
resource "proxmox_vm_qemu" "w11_vm" {
  name        = "W11-VM"
  target_node = var.target_node
  vmid        = 101
  
  # Configuration will be populated after import
  # Run: terraform import proxmox_vm_qemu.w11_vm pve/qemu/101
  
  lifecycle {
    # Prevent accidental destruction of existing VMs
    prevent_destroy = true
  }
}

# VM 102: linux-devbox (Container)
resource "proxmox_lxc" "linux_devbox" {
  hostname    = "linux-devbox"
  target_node = var.target_node
  vmid        = 102
  
  # Configuration will be populated after import
  # Run: terraform import proxmox_lxc.linux_devbox pve/lxc/102
  
  lifecycle {
    prevent_destroy = true
  }
}

# VM 103: k3s-master
resource "proxmox_vm_qemu" "k3s_master" {
  name        = "k3s-master"
  target_node = var.target_node
  vmid        = 103
  
  # Configuration will be populated after import
  # Run: terraform import proxmox_vm_qemu.k3s_master pve/qemu/103
  
  lifecycle {
    prevent_destroy = true
  }
}

# VM 104: k3s-worker1
resource "proxmox_vm_qemu" "k3s_worker1" {
  name        = "k3s-worker1"
  target_node = var.target_node
  vmid        = 104
  
  # Configuration will be populated after import
  # Run: terraform import proxmox_vm_qemu.k3s_worker1 pve/qemu/104
  
  lifecycle {
    prevent_destroy = true
  }
}

# VM 105: k3s-worker2
resource "proxmox_vm_qemu" "k3s_worker2" {
  name        = "k3s-worker2"
  target_node = var.target_node
  vmid        = 105
  
  # Configuration will be populated after import
  # Run: terraform import proxmox_vm_qemu.k3s_worker2 pve/qemu/105
  
  lifecycle {
    prevent_destroy = true
  }
}

# VM 100: ai-dev (Container, currently stopped)
resource "proxmox_lxc" "ai_dev" {
  hostname    = "ai-dev"
  target_node = var.target_node
  vmid        = 100
  
  # Configuration will be populated after import
  # Run: terraform import proxmox_lxc.ai_dev pve/lxc/100
  
  lifecycle {
    prevent_destroy = true
  }
}