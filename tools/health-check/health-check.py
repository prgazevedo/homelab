#!/usr/bin/env python3

import asyncio
import aiohttp
import json
import sys
import argparse
from typing import Dict, List, Any, Optional
import subprocess
from datetime import datetime

class HealthChecker:
    def __init__(self):
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'checks': {},
            'summary': {
                'total': 0,
                'passed': 0,
                'failed': 0,
                'warnings': 0
            }
        }
    
    async def check_proxmox_api(self, host: str, timeout: int = 5) -> Dict[str, Any]:
        """Check if Proxmox API is accessible"""
        url = f"https://{host}:8006/api2/json/version"
        
        try:
            connector = aiohttp.TCPConnector(ssl=False)
            async with aiohttp.ClientSession(connector=connector, timeout=aiohttp.ClientTimeout(total=timeout)) as session:
                async with session.get(url) as response:
                    if response.status == 200:
                        data = await response.json()
                        return {
                            'status': 'healthy',
                            'message': f"Proxmox API accessible, version: {data.get('data', {}).get('version', 'unknown')}",
                            'response_time': response.headers.get('X-Response-Time', 'unknown')
                        }
                    else:
                        return {
                            'status': 'unhealthy',
                            'message': f"Proxmox API returned status {response.status}"
                        }
        except asyncio.TimeoutError:
            return {
                'status': 'unhealthy',
                'message': f"Timeout connecting to Proxmox API after {timeout}s"
            }
        except Exception as e:
            return {
                'status': 'unhealthy',
                'message': f"Error connecting to Proxmox API: {str(e)}"
            }
    
    def check_k3s_cluster(self, kubeconfig: Optional[str] = None) -> Dict[str, Any]:
        """Check K3s cluster health"""
        cmd = ['kubectl', 'cluster-info']
        if kubeconfig:
            cmd.extend(['--kubeconfig', kubeconfig])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
            if result.returncode == 0:
                # Get node status
                node_cmd = ['kubectl', 'get', 'nodes', '--no-headers']
                if kubeconfig:
                    node_cmd.extend(['--kubeconfig', kubeconfig])
                
                node_result = subprocess.run(node_cmd, capture_output=True, text=True, timeout=10)
                if node_result.returncode == 0:
                    nodes = node_result.stdout.strip().split('\n')
                    ready_nodes = len([n for n in nodes if 'Ready' in n])
                    total_nodes = len(nodes)
                    
                    return {
                        'status': 'healthy' if ready_nodes == total_nodes else 'warning',
                        'message': f"K3s cluster accessible, {ready_nodes}/{total_nodes} nodes ready",
                        'nodes': {
                            'total': total_nodes,
                            'ready': ready_nodes
                        }
                    }
                else:
                    return {
                        'status': 'warning',
                        'message': "K3s cluster accessible but unable to get node status"
                    }
            else:
                return {
                    'status': 'unhealthy',
                    'message': f"K3s cluster not accessible: {result.stderr.strip()}"
                }
        except subprocess.TimeoutExpired:
            return {
                'status': 'unhealthy',
                'message': "Timeout checking K3s cluster"
            }
        except Exception as e:
            return {
                'status': 'unhealthy',
                'message': f"Error checking K3s cluster: {str(e)}"
            }
    
    async def check_service_endpoint(self, name: str, url: str, timeout: int = 5) -> Dict[str, Any]:
        """Check if a service endpoint is accessible"""
        try:
            connector = aiohttp.TCPConnector(ssl=False)
            async with aiohttp.ClientSession(connector=connector, timeout=aiohttp.ClientTimeout(total=timeout)) as session:
                async with session.get(url) as response:
                    return {
                        'status': 'healthy' if response.status < 400 else 'warning',
                        'message': f"{name} accessible (HTTP {response.status})",
                        'status_code': response.status
                    }
        except asyncio.TimeoutError:
            return {
                'status': 'unhealthy',
                'message': f"{name} timeout after {timeout}s"
            }
        except Exception as e:
            return {
                'status': 'unhealthy',
                'message': f"{name} error: {str(e)}"
            }
    
    def check_vm_status(self, vm_ips: List[str]) -> Dict[str, Any]:
        """Check if VMs are reachable via ping"""
        reachable = 0
        total = len(vm_ips)
        vm_status = {}
        
        for ip in vm_ips:
            try:
                result = subprocess.run(['ping', '-c', '1', '-W', '2', ip], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode == 0:
                    reachable += 1
                    vm_status[ip] = 'reachable'
                else:
                    vm_status[ip] = 'unreachable'
            except Exception as e:
                vm_status[ip] = f'error: {str(e)}'
        
        return {
            'status': 'healthy' if reachable == total else 'warning',
            'message': f"{reachable}/{total} VMs reachable",
            'reachable': reachable,
            'total': total,
            'details': vm_status
        }
    
    def add_result(self, check_name: str, result: Dict[str, Any]):
        """Add a check result"""
        self.results['checks'][check_name] = result
        self.results['summary']['total'] += 1
        
        status = result.get('status', 'unknown')
        if status == 'healthy':
            self.results['summary']['passed'] += 1
        elif status == 'warning':
            self.results['summary']['warnings'] += 1
        else:
            self.results['summary']['failed'] += 1
    
    async def run_all_checks(self, config: Dict[str, Any]):
        """Run all health checks"""
        # Check Proxmox API
        if 'proxmox_host' in config:
            result = await self.check_proxmox_api(config['proxmox_host'])
            self.add_result('proxmox_api', result)
        
        # Check K3s cluster
        result = self.check_k3s_cluster(config.get('kubeconfig'))
        self.add_result('k3s_cluster', result)
        
        # Check VM connectivity
        if 'vm_ips' in config:
            result = self.check_vm_status(config['vm_ips'])
            self.add_result('vm_connectivity', result)
        
        # Check service endpoints
        if 'services' in config:
            tasks = []
            for service_name, service_url in config['services'].items():
                task = self.check_service_endpoint(service_name, service_url)
                tasks.append((service_name, task))
            
            for service_name, task in tasks:
                result = await task
                self.add_result(f'service_{service_name}', result)
    
    def print_summary(self):
        """Print a summary of health check results"""
        summary = self.results['summary']
        print(f"\n🏥 Homelab Health Check Summary")
        print(f"=" * 40)
        print(f"Total checks: {summary['total']}")
        print(f"✅ Passed: {summary['passed']}")
        print(f"⚠️  Warnings: {summary['warnings']}")
        print(f"❌ Failed: {summary['failed']}")
        print(f"Timestamp: {self.results['timestamp']}")
        print()
        
        for check_name, result in self.results['checks'].items():
            status = result.get('status', 'unknown')
            message = result.get('message', 'No message')
            
            if status == 'healthy':
                emoji = "✅"
            elif status == 'warning':
                emoji = "⚠️ "
            else:
                emoji = "❌"
            
            print(f"{emoji} {check_name}: {message}")
        
        # Overall health
        if summary['failed'] > 0:
            print(f"\n🚨 Overall Status: CRITICAL - {summary['failed']} critical issues")
            return False
        elif summary['warnings'] > 0:
            print(f"\n⚠️  Overall Status: WARNING - {summary['warnings']} warnings")
            return True
        else:
            print(f"\n🎉 Overall Status: HEALTHY - All systems operational")
            return True

def load_config(config_file: str) -> Dict[str, Any]:
    """Load configuration from file"""
    try:
        with open(config_file, 'r') as f:
            return json.load(f)
    except Exception as e:
        print(f"Error loading config file {config_file}: {e}")
        sys.exit(1)

async def main():
    parser = argparse.ArgumentParser(description='Homelab health checker')
    parser.add_argument('--config', '-c', help='Configuration file (JSON)', 
                       default='health-check-config.json')
    parser.add_argument('--proxmox-host', help='Proxmox host IP (overrides config)')
    parser.add_argument('--kubeconfig', help='Kubeconfig file path (overrides config)')
    parser.add_argument('--output', '-o', help='Output file for JSON results')
    parser.add_argument('--quiet', '-q', action='store_true', help='Quiet mode (JSON only)')
    
    args = parser.parse_args()
    
    # Default configuration
    config = {
        'proxmox_host': '192.168.2.100',
        'vm_ips': ['192.168.2.103', '192.168.2.104', '192.168.2.105'],
        'services': {
            'argocd': 'http://192.168.2.103:30080',
            'grafana': 'http://192.168.2.103:3000'
        }
    }
    
    # Load config file if it exists
    try:
        if args.config:
            file_config = load_config(args.config)
            config.update(file_config)
    except:
        pass  # Use default config if file doesn't exist
    
    # Override with command line arguments
    if args.proxmox_host:
        config['proxmox_host'] = args.proxmox_host
    if args.kubeconfig:
        config['kubeconfig'] = args.kubeconfig
    
    # Run health checks
    checker = HealthChecker()
    await checker.run_all_checks(config)
    
    # Output results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(checker.results, f, indent=2)
        if not args.quiet:
            print(f"Results saved to {args.output}")
    
    if not args.quiet:
        is_healthy = checker.print_summary()
        sys.exit(0 if is_healthy else 1)
    else:
        print(json.dumps(checker.results, indent=2))

if __name__ == "__main__":
    asyncio.run(main())