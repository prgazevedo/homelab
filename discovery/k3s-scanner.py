#!/usr/bin/env python3

import json
import yaml
import argparse
import sys
import subprocess
import os
from typing import Dict, List, Any, Optional
import tempfile

class K3sScanner:
    def __init__(self, kubeconfig_path: Optional[str] = None, context: Optional[str] = None):
        self.kubeconfig_path = kubeconfig_path
        self.context = context
        self.kubectl_cmd = self._build_kubectl_cmd()
    
    def _build_kubectl_cmd(self) -> List[str]:
        """Build kubectl command with proper kubeconfig and context"""
        cmd = ['kubectl']
        
        if self.kubeconfig_path:
            cmd.extend(['--kubeconfig', self.kubeconfig_path])
        
        if self.context:
            cmd.extend(['--context', self.context])
        
        return cmd
    
    def _run_kubectl(self, args: List[str], output_format: str = 'json') -> Dict[str, Any]:
        """Run kubectl command and return parsed output"""
        cmd = self.kubectl_cmd + args
        
        if output_format == 'json':
            cmd.extend(['-o', 'json'])
        elif output_format == 'yaml':
            cmd.extend(['-o', 'yaml'])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, check=True)
            
            if output_format == 'json':
                return json.loads(result.stdout)
            elif output_format == 'yaml':
                return yaml.safe_load(result.stdout)
            else:
                return {'output': result.stdout.strip()}
        
        except subprocess.CalledProcessError as e:
            raise Exception(f"kubectl command failed: {e.stderr}")
        except json.JSONDecodeError as e:
            raise Exception(f"Failed to parse kubectl JSON output: {e}")
        except yaml.YAMLError as e:
            raise Exception(f"Failed to parse kubectl YAML output: {e}")
    
    def get_cluster_info(self) -> Dict[str, Any]:
        """Get basic cluster information"""
        try:
            # Get cluster info
            cluster_info = self._run_kubectl(['cluster-info'], output_format='text')
            
            # Get version info
            version_info = self._run_kubectl(['version', '--short'], output_format='text')
            
            return {
                'cluster_info': cluster_info.get('output', ''),
                'version_info': version_info.get('output', '')
            }
        except Exception as e:
            return {'error': str(e)}
    
    def get_nodes(self) -> Dict[str, Any]:
        """Get all nodes in the cluster"""
        try:
            nodes = self._run_kubectl(['get', 'nodes'])
            
            # Get detailed node information
            detailed_nodes = []
            for node in nodes.get('items', []):
                node_name = node['metadata']['name']
                try:
                    node_detail = self._run_kubectl(['describe', 'node', node_name], output_format='text')
                    node['describe'] = node_detail.get('output', '')
                except Exception:
                    node['describe'] = 'Unable to get node details'
                detailed_nodes.append(node)
            
            nodes['items'] = detailed_nodes
            return nodes
        
        except Exception as e:
            return {'error': str(e)}
    
    def get_namespaces(self) -> Dict[str, Any]:
        """Get all namespaces"""
        try:
            return self._run_kubectl(['get', 'namespaces'])
        except Exception as e:
            return {'error': str(e)}
    
    def get_workloads(self) -> Dict[str, Any]:
        """Get all workloads (deployments, statefulsets, daemonsets, jobs)"""
        workloads = {}
        
        workload_types = [
            'deployments',
            'statefulsets',
            'daemonsets',
            'jobs',
            'cronjobs',
            'replicasets'
        ]
        
        for workload_type in workload_types:
            try:
                result = self._run_kubectl(['get', workload_type, '--all-namespaces'])
                workloads[workload_type] = result
            except Exception as e:
                workloads[workload_type] = {'error': str(e)}
        
        return workloads
    
    def get_services(self) -> Dict[str, Any]:
        """Get all services"""
        try:
            return self._run_kubectl(['get', 'services', '--all-namespaces'])
        except Exception as e:
            return {'error': str(e)}
    
    def get_ingresses(self) -> Dict[str, Any]:
        """Get all ingresses"""
        try:
            return self._run_kubectl(['get', 'ingresses', '--all-namespaces'])
        except Exception as e:
            return {'error': str(e)}
    
    def get_configmaps(self) -> Dict[str, Any]:
        """Get all configmaps"""
        try:
            return self._run_kubectl(['get', 'configmaps', '--all-namespaces'])
        except Exception as e:
            return {'error': str(e)}
    
    def get_secrets(self) -> Dict[str, Any]:
        """Get all secrets (names only for security)"""
        try:
            secrets = self._run_kubectl(['get', 'secrets', '--all-namespaces'])
            # Remove sensitive data, keep only metadata
            if 'items' in secrets:
                for secret in secrets['items']:
                    if 'data' in secret:
                        secret['data'] = {k: '<REDACTED>' for k in secret['data'].keys()}
                    # Also redact stringData if present
                    if 'stringData' in secret:
                        secret['stringData'] = {k: '<REDACTED>' for k in secret['stringData'].keys()}
            return secrets
        except Exception as e:
            return {'error': str(e)}
    
    def get_persistent_volumes(self) -> Dict[str, Any]:
        """Get persistent volumes and claims"""
        try:
            pvs = self._run_kubectl(['get', 'persistentvolumes'])
            pvcs = self._run_kubectl(['get', 'persistentvolumeclaims', '--all-namespaces'])
            
            return {
                'persistent_volumes': pvs,
                'persistent_volume_claims': pvcs
            }
        except Exception as e:
            return {'error': str(e)}
    
    def get_storage_classes(self) -> Dict[str, Any]:
        """Get storage classes"""
        try:
            return self._run_kubectl(['get', 'storageclasses'])
        except Exception as e:
            return {'error': str(e)}
    
    def get_helm_releases(self) -> Dict[str, Any]:
        """Get Helm releases if Helm is available"""
        try:
            # Try to get Helm releases
            result = subprocess.run(['helm', 'list', '--all-namespaces', '-o', 'json'], 
                                  capture_output=True, text=True, check=True)
            return json.loads(result.stdout)
        except (subprocess.CalledProcessError, FileNotFoundError, json.JSONDecodeError):
            return {'error': 'Helm not available or no releases found'}
    
    def get_argocd_applications(self) -> Dict[str, Any]:
        """Get ArgoCD applications if ArgoCD is installed"""
        try:
            return self._run_kubectl(['get', 'applications', '--all-namespaces'])
        except Exception as e:
            return {'error': str(e)}
    
    def export_manifests(self, output_dir: str) -> Dict[str, Any]:
        """Export all cluster manifests to files"""
        os.makedirs(output_dir, exist_ok=True)
        
        export_results = {}
        
        # Export different resource types
        resource_types = [
            'deployments',
            'statefulsets',
            'daemonsets',
            'services',
            'configmaps',
            'ingresses',
            'persistentvolumeclaims',
            'serviceaccounts',
            'roles',
            'rolebindings',
            'clusterroles',
            'clusterrolebindings'
        ]
        
        for resource_type in resource_types:
            try:
                # Get all namespaces for this resource
                result = self._run_kubectl(['get', resource_type, '--all-namespaces'], output_format='yaml')
                
                if 'items' in result and result['items']:
                    output_file = os.path.join(output_dir, f"{resource_type}.yaml")
                    with open(output_file, 'w') as f:
                        yaml.dump(result, f, default_flow_style=False)
                    
                    export_results[resource_type] = {
                        'count': len(result['items']),
                        'file': output_file
                    }
                else:
                    export_results[resource_type] = {'count': 0, 'file': None}
            
            except Exception as e:
                export_results[resource_type] = {'error': str(e)}
        
        return export_results
    
    def scan_cluster(self) -> Dict[str, Any]:
        """Perform complete cluster scan"""
        cluster_data = {
            'cluster_info': self.get_cluster_info(),
            'nodes': self.get_nodes(),
            'namespaces': self.get_namespaces(),
            'workloads': self.get_workloads(),
            'services': self.get_services(),
            'ingresses': self.get_ingresses(),
            'configmaps': self.get_configmaps(),
            'secrets': self.get_secrets(),
            'storage': {
                'persistent_volumes': self.get_persistent_volumes(),
                'storage_classes': self.get_storage_classes()
            },
            'helm_releases': self.get_helm_releases(),
            'argocd_applications': self.get_argocd_applications()
        }
        
        # Add summary
        summary = {
            'total_nodes': len(cluster_data['nodes'].get('items', [])) if 'items' in cluster_data['nodes'] else 0,
            'total_namespaces': len(cluster_data['namespaces'].get('items', [])) if 'items' in cluster_data['namespaces'] else 0,
            'total_services': len(cluster_data['services'].get('items', [])) if 'items' in cluster_data['services'] else 0
        }
        
        # Count workloads
        for workload_type, workload_data in cluster_data['workloads'].items():
            if 'items' in workload_data:
                summary[f'total_{workload_type}'] = len(workload_data['items'])
        
        cluster_data['summary'] = summary
        
        return cluster_data
    
    def sanitize_cluster_data(self, cluster_data: Dict[str, Any]) -> Dict[str, Any]:
        """Remove sensitive information from cluster data before output"""
        import copy
        sanitized_data = copy.deepcopy(cluster_data)
        
        # Additional sanitization for other potential sensitive fields
        def sanitize_recursive(obj):
            if isinstance(obj, dict):
                for key, value in obj.items():
                    # Sanitize common sensitive field names
                    if any(sensitive_key in key.lower() for sensitive_key in 
                          ['password', 'token', 'secret', 'key', 'credential', 'auth']):
                        if isinstance(value, str) and value:
                            obj[key] = '<REDACTED>'
                        elif isinstance(value, dict):
                            obj[key] = {k: '<REDACTED>' for k in value.keys()}
                    else:
                        sanitize_recursive(value)
            elif isinstance(obj, list):
                for item in obj:
                    sanitize_recursive(item)
        
        sanitize_recursive(sanitized_data)
        return sanitized_data

def main():
    parser = argparse.ArgumentParser(description='Discover K3s cluster configuration')
    parser.add_argument('--kubeconfig', help='Path to kubeconfig file')
    parser.add_argument('--context', help='Kubernetes context to use')
    parser.add_argument('--output', '-o', help='Output file (default: stdout)')
    parser.add_argument('--format', choices=['json', 'summary'], default='json',
                       help='Output format (default: json)')
    parser.add_argument('--export-manifests', help='Export all manifests to directory')
    
    args = parser.parse_args()
    
    scanner = K3sScanner(args.kubeconfig, args.context)
    
    try:
        cluster_data = scanner.scan_cluster()
        
        # Export manifests if requested
        if args.export_manifests:
            export_results = scanner.export_manifests(args.export_manifests)
            cluster_data['export_results'] = export_results
            print(f"Manifests exported to {args.export_manifests}")
        
        if args.format == 'summary':
            # Print summary - safe to output counts and names (no sensitive data)
            summary = cluster_data.get('summary', {})
            print(f"K3s Cluster Summary")
            print(f"=" * 30)
            print(f"Nodes: {summary.get('total_nodes', 0)}")  # codeql[py/clear-text-logging-sensitive-data]
            print(f"Namespaces: {summary.get('total_namespaces', 0)}")  # codeql[py/clear-text-logging-sensitive-data]  
            print(f"Services: {summary.get('total_services', 0)}")  # codeql[py/clear-text-logging-sensitive-data]
            print(f"Deployments: {summary.get('total_deployments', 0)}")  # codeql[py/clear-text-logging-sensitive-data]
            print(f"StatefulSets: {summary.get('total_statefulsets', 0)}")  # codeql[py/clear-text-logging-sensitive-data]
            print(f"DaemonSets: {summary.get('total_daemonsets', 0)}")  # codeql[py/clear-text-logging-sensitive-data]
            print()
            
            # Show nodes - safe to output node names and status (no sensitive data)
            nodes = cluster_data.get('nodes', {}).get('items', [])
            if nodes:
                print("Nodes:")
                for node in nodes:
                    name = node.get('metadata', {}).get('name', 'unknown')
                    status = 'Unknown'
                    for condition in node.get('status', {}).get('conditions', []):
                        if condition.get('type') == 'Ready':
                            status = 'Ready' if condition.get('status') == 'True' else 'NotReady'
                            break
                    print(f"  {name}: {status}")  # codeql[py/clear-text-logging-sensitive-data]
            
            print()
            # Show namespaces - safe to output namespace names (no sensitive data)
            namespaces = cluster_data.get('namespaces', {}).get('items', [])
            if namespaces:
                print("Namespaces:")
                for ns in namespaces:
                    name = ns.get('metadata', {}).get('name', 'unknown')
                    print(f"  {name}")  # codeql[py/clear-text-logging-sensitive-data]
        
        else:
            # JSON output - sanitize sensitive data before output
            sanitized_data = scanner.sanitize_cluster_data(cluster_data)
            output = json.dumps(sanitized_data, indent=2, default=str)
            
            if args.output:
                with open(args.output, 'w') as f:
                    f.write(output)
                print(f"Cluster data saved to {args.output}")
            else:
                print(output)
    
    except Exception as e:
        print(f"Error scanning cluster: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()