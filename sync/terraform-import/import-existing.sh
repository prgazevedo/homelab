#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "${SCRIPT_DIR}/../../terraform" && pwd)"

echo "🔍 Terraform Import Script for Existing Proxmox VMs"
echo "=================================================="

cd "${TERRAFORM_DIR}"

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "📦 Initializing Terraform..."
    terraform init
fi

# Function to import a resource if it doesn't exist in state
import_resource() {
    local resource_type="$1"
    local resource_name="$2"
    local import_id="$3"
    
    echo "🔄 Checking if ${resource_type}.${resource_name} exists in state..."
    
    if terraform state show "${resource_type}.${resource_name}" >/dev/null 2>&1; then
        echo "✅ ${resource_type}.${resource_name} already exists in state"
    else
        echo "📥 Importing ${resource_type}.${resource_name} with ID: ${import_id}"
        terraform import "${resource_type}.${resource_name}" "${import_id}"
        echo "✅ Successfully imported ${resource_type}.${resource_name}"
    fi
}

echo ""
echo "🚀 Starting import process..."
echo ""

# Import existing VMs
echo "📋 Importing VMs..."

# Import QEMU VMs
import_resource "proxmox_vm_qemu" "w11_vm" "pve/qemu/101"
import_resource "proxmox_vm_qemu" "k3s_master" "pve/qemu/103"
import_resource "proxmox_vm_qemu" "k3s_worker1" "pve/qemu/104"
import_resource "proxmox_vm_qemu" "k3s_worker2" "pve/qemu/105"

# Import LXC Containers
import_resource "proxmox_lxc" "linux_devbox" "pve/lxc/102"
import_resource "proxmox_lxc" "ai_dev" "pve/lxc/100"

echo ""
echo "🔍 Checking state after import..."
terraform state list

echo ""
echo "⚠️  IMPORTANT: Next Steps"
echo "========================"
echo "1. Run 'terraform plan' to see configuration drift"
echo "2. Update the Terraform configurations in imported/ to match current state"
echo "3. Run 'terraform plan' again to ensure no changes are detected"
echo "4. Only then should you make intentional changes through Terraform"
echo ""
echo "💡 Tip: Use 'terraform show <resource>' to see the current state details"
echo "   Example: terraform show proxmox_vm_qemu.k3s_master"
echo ""
echo "✅ Import process completed!"