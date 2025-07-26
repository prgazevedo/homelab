#!/usr/bin/env python3

import json
import argparse
import sys
from typing import Dict, List, Any
import urllib3
import requests
from requests.auth import HTTPBasicAuth

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

class ProxmoxScanner:
    def __init__(self, host: str, username: str, password: str, verify_ssl: bool = False):
        self.host = host
        self.base_url = f"https://{host}:8006/api2/json"
        self.username = username
        self.password = password
        self.verify_ssl = verify_ssl
        self.ticket = None
        self.csrf_token = None
    
    def authenticate(self) -> bool:
        """Authenticate with Proxmox and get ticket/CSRF token"""
        auth_url = f"{self.base_url}/access/ticket"
        auth_data = {
            'username': self.username,
            'password': self.password
        }
        
        try:
            response = requests.post(auth_url, data=auth_data, verify=self.verify_ssl, timeout=30)
            response.raise_for_status()
            
            auth_result = response.json()
            if 'data' in auth_result:
                self.ticket = auth_result['data']['ticket']
                self.csrf_token = auth_result['data']['CSRFPreventionToken']
                return True
        except Exception as e:
            print(f"Authentication failed: {e}")
            return False
        
        return False
    
    def make_request(self, endpoint: str) -> Dict[str, Any]:
        """Make authenticated request to Proxmox API"""
        if not self.ticket:
            if not self.authenticate():
                raise Exception("Authentication failed")
        
        headers = {
            'CSRFPreventionToken': self.csrf_token
        }
        cookies = {
            'PVEAuthCookie': self.ticket
        }
        
        url = f"{self.base_url}{endpoint}"
        response = requests.get(url, headers=headers, cookies=cookies, verify=self.verify_ssl, timeout=30)
        response.raise_for_status()
        
        return response.json()
    
    def get_nodes(self) -> List[Dict[str, Any]]:
        """Get all Proxmox nodes"""
        result = self.make_request("/nodes")
        return result.get('data', [])
    
    def get_vms(self, node: str) -> List[Dict[str, Any]]:
        """Get all VMs for a specific node"""
        result = self.make_request(f"/nodes/{node}/qemu")
        return result.get('data', [])
    
    def get_containers(self, node: str) -> List[Dict[str, Any]]:
        """Get all containers for a specific node"""
        result = self.make_request(f"/nodes/{node}/lxc")
        return result.get('data', [])
    
    def get_vm_config(self, node: str, vmid: str) -> Dict[str, Any]:
        """Get detailed VM configuration"""
        result = self.make_request(f"/nodes/{node}/qemu/{vmid}/config")
        return result.get('data', {})
    
    def get_container_config(self, node: str, vmid: str) -> Dict[str, Any]:
        """Get detailed container configuration"""
        result = self.make_request(f"/nodes/{node}/lxc/{vmid}/config")
        return result.get('data', {})
    
    def get_storage(self) -> List[Dict[str, Any]]:
        """Get storage information"""
        result = self.make_request("/storage")
        return result.get('data', [])
    
    def get_networks(self, node: str) -> List[Dict[str, Any]]:
        """Get network configuration"""
        result = self.make_request(f"/nodes/{node}/network")
        return result.get('data', [])
    
    def scan_infrastructure(self) -> Dict[str, Any]:
        """Perform complete infrastructure scan"""
        infrastructure = {
            'nodes': [],
            'vms': [],
            'containers': [],
            'storage': [],
            'networks': [],
            'summary': {
                'total_vms': 0,
                'total_containers': 0,
                'running_vms': 0,
                'running_containers': 0
            }
        }
        
        # Get nodes
        nodes = self.get_nodes()
        infrastructure['nodes'] = nodes
        
        for node in nodes:
            node_name = node['node']
            
            # Get VMs
            vms = self.get_vms(node_name)
            for vm in vms:
                vm_detail = vm.copy()
                vm_detail['node'] = node_name
                vm_detail['type'] = 'qemu'
                
                # Get detailed config
                try:
                    config = self.get_vm_config(node_name, str(vm['vmid']))
                    vm_detail['config'] = config
                except Exception as e:
                    print(f"Warning: Could not get config for VM {vm['vmid']}: {e}")
                    vm_detail['config'] = {}
                
                infrastructure['vms'].append(vm_detail)
                infrastructure['summary']['total_vms'] += 1
                if vm.get('status') == 'running':
                    infrastructure['summary']['running_vms'] += 1
            
            # Get containers
            containers = self.get_containers(node_name)
            for container in containers:
                container_detail = container.copy()
                container_detail['node'] = node_name
                container_detail['type'] = 'lxc'
                
                # Get detailed config
                try:
                    config = self.get_container_config(node_name, str(container['vmid']))
                    container_detail['config'] = config
                except Exception as e:
                    print(f"Warning: Could not get config for container {container['vmid']}: {e}")
                    container_detail['config'] = {}
                
                infrastructure['containers'].append(container_detail)
                infrastructure['summary']['total_containers'] += 1
                if container.get('status') == 'running':
                    infrastructure['summary']['running_containers'] += 1
            
            # Get networks (only from first node to avoid duplication)
            if node_name == nodes[0]['node']:
                try:
                    networks = self.get_networks(node_name)
                    infrastructure['networks'] = networks
                except Exception as e:
                    print(f"Warning: Could not get network info: {e}")
        
        # Get storage
        try:
            storage = self.get_storage()
            infrastructure['storage'] = storage
        except Exception as e:
            print(f"Warning: Could not get storage info: {e}")
        
        return infrastructure

def main():
    parser = argparse.ArgumentParser(description='Discover Proxmox infrastructure')
    parser.add_argument('--host', required=True, help='Proxmox host IP or hostname')
    parser.add_argument('--username', required=True, help='Proxmox username (e.g., root@pam)')
    parser.add_argument('--password', required=True, help='Proxmox password')
    parser.add_argument('--output', '-o', help='Output file (default: stdout)')
    parser.add_argument('--format', choices=['json', 'summary'], default='json', 
                       help='Output format (default: json)')
    parser.add_argument('--verify-ssl', action='store_true', help='Verify SSL certificates')
    
    args = parser.parse_args()
    
    scanner = ProxmoxScanner(args.host, args.username, args.password, args.verify_ssl)
    
    try:
        infrastructure = scanner.scan_infrastructure()
        
        if args.format == 'summary':
            # Print summary
            summary = infrastructure['summary']
            print(f"Proxmox Infrastructure Summary for {args.host}")
            print(f"=" * 50)
            print(f"Total VMs: {summary['total_vms']} (Running: {summary['running_vms']})")
            print(f"Total Containers: {summary['total_containers']} (Running: {summary['running_containers']})")
            print(f"Nodes: {len(infrastructure['nodes'])}")
            print(f"Storage pools: {len(infrastructure['storage'])}")
            print()
            
            print("VMs:")
            for vm in infrastructure['vms']:
                status = vm.get('status', 'unknown')
                memory = vm.get('maxmem', 0) // (1024**3) if vm.get('maxmem') else 0
                cores = vm.get('cpus', 0)
                print(f"  VM {vm['vmid']}: {vm.get('name', 'unnamed')} ({status}) - {cores} CPU, {memory}GB RAM")
            
            print("\nContainers:")
            for ct in infrastructure['containers']:
                status = ct.get('status', 'unknown')
                memory = ct.get('maxmem', 0) // (1024**3) if ct.get('maxmem') else 0
                cores = ct.get('cpus', 0)
                print(f"  CT {ct['vmid']}: {ct.get('name', 'unnamed')} ({status}) - {cores} CPU, {memory}GB RAM")
        
        else:
            # JSON output
            output = json.dumps(infrastructure, indent=2, default=str)
            
            if args.output:
                with open(args.output, 'w') as f:
                    f.write(output)
                print(f"Infrastructure data saved to {args.output}")
            else:
                print(output)
    
    except Exception as e:
        print(f"Error scanning infrastructure: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()