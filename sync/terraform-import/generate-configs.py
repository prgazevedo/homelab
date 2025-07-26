#!/usr/bin/env python3

import json
import sys
import argparse
from typing import Dict, Any

def format_terraform_value(value):
    """Format a value for Terraform configuration"""
    if isinstance(value, bool):
        return "true" if value else "false"
    elif isinstance(value, str):
        return f'"{value}"'
    elif isinstance(value, (int, float)):
        return str(value)
    elif isinstance(value, list):
        if all(isinstance(item, str) for item in value):
            return "[" + ", ".join(f'"{item}"' for item in value) + "]"
        else:
            return "[" + ", ".join(str(item) for item in value) + "]"
    else:
        return f'"{str(value)}"'

def generate_qemu_config(vm_data: Dict[str, Any], resource_name: str) -> str:
    """Generate Terraform configuration for a QEMU VM"""
    config = vm_data.get('config', {})
    
    # Extract common settings
    memory = config.get('memory', 4096)
    cores = config.get('cores', 2)
    sockets = config.get('sockets', 1)
    
    # Extract disk information
    disks = []
    for key, value in config.items():
        if key.startswith('scsi') or key.startswith('ide') or key.startswith('virtio'):
            disks.append(f"    # {key} = {format_terraform_value(value)}")
    
    # Extract network information
    networks = []
    for key, value in config.items():
        if key.startswith('net'):
            networks.append(f"    # {key} = {format_terraform_value(value)}")
    
    # Generate the configuration
    config_str = f'''resource "proxmox_vm_qemu" "{resource_name}" {{
  name        = {format_terraform_value(vm_data.get('name', 'unknown'))}
  target_node = var.target_node
  vmid        = {vm_data.get('vmid', 0)}
  
  # System configuration
  memory    = {memory}
  cores     = {cores}
  sockets   = {sockets}
  cpu       = {format_terraform_value(config.get('cpu', 'host'))}
  ostype    = {format_terraform_value(config.get('ostype', 'l26'))}
  
  # Boot configuration
  boot      = {format_terraform_value(config.get('boot', 'cdn'))}
  bootdisk  = {format_terraform_value(config.get('bootdisk', 'scsi0'))}
  
  # Agent and features
  agent     = {format_terraform_value(config.get('agent', 1))}
  
  # Disks (review and uncomment as needed)
{chr(10).join(disks)}
  
  # Network (review and uncomment as needed)
{chr(10).join(networks)}
  
  lifecycle {{
    prevent_destroy = true
  }}
}}'''
    
    return config_str

def generate_lxc_config(container_data: Dict[str, Any], resource_name: str) -> str:
    """Generate Terraform configuration for an LXC container"""
    config = container_data.get('config', {})
    
    # Extract common settings
    memory = config.get('memory', 512)
    cores = config.get('cores', 1)
    
    # Extract other settings
    ostemplate = config.get('ostemplate', 'unknown')
    
    config_str = f'''resource "proxmox_lxc" "{resource_name}" {{
  hostname    = {format_terraform_value(container_data.get('name', 'unknown'))}
  target_node = var.target_node
  vmid        = {container_data.get('vmid', 0)}
  
  # System configuration
  memory      = {memory}
  cores       = {cores}
  ostemplate  = {format_terraform_value(ostemplate)}
  
  # Network configuration (review and update as needed)
  # network {{
  #   name   = "eth0"
  #   bridge = "vmbr0"
  #   ip     = "dhcp"
  # }}
  
  # Storage configuration (review and update as needed)
  # rootfs {{
  #   storage = "local-lvm"
  #   size    = "8G"
  # }}
  
  lifecycle {{
    prevent_destroy = true
  }}
}}'''
    
    return config_str

def main():
    parser = argparse.ArgumentParser(description='Generate Terraform configs from Proxmox discovery data')
    parser.add_argument('--input', '-i', required=True, help='Input JSON file from proxmox-scanner.py')
    parser.add_argument('--output', '-o', help='Output directory (default: terraform/imported/)')
    parser.add_argument('--vm-id', help='Generate config for specific VM ID only')
    
    args = parser.parse_args()
    
    try:
        with open(args.input, 'r') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error reading input file: {e}")
        sys.exit(1)
    
    output_dir = args.output or "terraform/imported/"
    
    # Generate configs for VMs
    vm_configs = []
    if 'vms' in data:
        for vm in data['vms']:
            vmid = str(vm.get('vmid', ''))
            if args.vm_id and vmid != args.vm_id:
                continue
                
            name = vm.get('name', f'vm_{vmid}')
            resource_name = name.lower().replace('-', '_').replace(' ', '_')
            
            config = generate_qemu_config(vm, resource_name)
            vm_configs.append(f"# VM {vmid}: {name}")
            vm_configs.append(config)
            vm_configs.append("")
    
    # Generate configs for containers
    container_configs = []
    if 'containers' in data:
        for container in data['containers']:
            vmid = str(container.get('vmid', ''))
            if args.vm_id and vmid != args.vm_id:
                continue
                
            name = container.get('name', f'container_{vmid}')
            resource_name = name.lower().replace('-', '_').replace(' ', '_')
            
            config = generate_lxc_config(container, resource_name)
            container_configs.append(f"# Container {vmid}: {name}")
            container_configs.append(config)
            container_configs.append("")
    
    # Combine all configs
    all_configs = []
    all_configs.append("# Generated Terraform configurations from Proxmox discovery")
    all_configs.append("# Review and update these configurations before applying")
    all_configs.append("")
    
    if vm_configs:
        all_configs.append("# QEMU VMs")
        all_configs.extend(vm_configs)
    
    if container_configs:
        all_configs.append("# LXC Containers")
        all_configs.extend(container_configs)
    
    # Output the configurations
    config_content = "\n".join(all_configs)
    
    if args.output:
        import os
        os.makedirs(args.output, exist_ok=True)
        output_file = os.path.join(args.output, "generated-configs.tf")
        with open(output_file, 'w') as f:
            f.write(config_content)
        print(f"Generated Terraform configurations saved to {output_file}")
    else:
        print(config_content)

if __name__ == "__main__":
    main()