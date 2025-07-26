.PHONY: help discover import sync health monitor terraform-init terraform-plan terraform-apply clean

# Default target
help: ## Show this help message
	@echo "🏠 Homelab Infrastructure Management"
	@echo "===================================="
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Discovery commands
discover: ## Discover current Proxmox and K3s infrastructure
	@echo "🔍 Discovering Proxmox infrastructure..."
	@read -p "Enter Proxmox password: " -s password && \
	python3 discovery/proxmox-scanner.py \
		--host 192.168.2.100 \
		--username root@pam \
		--password $$password \
		--output discovery/proxmox-current.json \
		--format summary
	@echo ""
	@echo "🔍 Discovering K3s cluster..."
	@python3 discovery/k3s-scanner.py \
		--output discovery/k3s-current.json \
		--format summary

discover-proxmox: ## Discover only Proxmox infrastructure
	@echo "🔍 Discovering Proxmox infrastructure..."
	@read -p "Enter Proxmox password: " -s password && \
	python3 discovery/proxmox-scanner.py \
		--host 192.168.2.100 \
		--username root@pam \
		--password $$password \
		--output discovery/proxmox-current.json \
		--format summary

discover-k3s: ## Discover only K3s cluster
	@echo "🔍 Discovering K3s cluster..."
	@python3 discovery/k3s-scanner.py \
		--output discovery/k3s-current.json \
		--format summary

# Import and sync commands
import: terraform-init ## Import existing infrastructure into Terraform
	@echo "📥 Importing existing VMs into Terraform..."
	@cd terraform && bash ../sync/terraform-import/import-existing.sh

sync: ## Sync current state with IaC (run after import)
	@echo "🔄 Syncing current state with Infrastructure as Code..."
	@if [ ! -f discovery/proxmox-current.json ]; then \
		echo "❌ Please run 'make discover' first"; \
		exit 1; \
	fi
	@python3 sync/terraform-import/generate-configs.py \
		--input discovery/proxmox-current.json \
		--output terraform/imported/
	@echo "✅ Generated Terraform configs from current state"
	@echo "📝 Review the generated configs in terraform/imported/"
	@echo "🔧 Run 'make terraform-plan' to see any drift"

# Terraform commands
terraform-init: ## Initialize Terraform
	@echo "🚀 Initializing Terraform..."
	@cd terraform && terraform init

terraform-plan: terraform-init ## Plan Terraform changes
	@echo "📋 Planning Terraform changes..."
	@cd terraform && terraform plan

terraform-apply: terraform-init ## Apply Terraform changes
	@echo "⚡ Applying Terraform changes..."
	@cd terraform && terraform apply

terraform-show: ## Show Terraform state
	@cd terraform && terraform state list

# Health and monitoring
health: ## Run health checks on the infrastructure
	@echo "🏥 Running health checks..."
	@python3 tools/health-check/health-check.py

health-json: ## Run health checks and output JSON
	@python3 tools/health-check/health-check.py --quiet

monitor: ## Set up monitoring (placeholder for future implementation)
	@echo "📊 Setting up monitoring..."
	@echo "🚧 Monitor setup not yet implemented"
	@echo "📁 Monitoring configs available in monitoring/"

# Export and backup
export-k8s: ## Export all K8s manifests
	@echo "📤 Exporting K8s manifests..."
	@mkdir -p exports/k8s-manifests
	@python3 discovery/k3s-scanner.py \
		--export-manifests exports/k8s-manifests \
		--format summary

backup: ## Create backup of current configurations
	@echo "💾 Creating backup..."
	@mkdir -p backups/$(shell date +%Y%m%d-%H%M%S)
	@$(MAKE) discover
	@$(MAKE) export-k8s
	@cp -r discovery exports backups/$(shell date +%Y%m%d-%H%M%S)/
	@echo "✅ Backup created in backups/$(shell date +%Y%m%d-%H%M%S)/"

# Validation and testing
validate: ## Validate Terraform configurations
	@echo "✅ Validating Terraform configurations..."
	@cd terraform && terraform validate

test: ## Run infrastructure tests
	@echo "🧪 Running infrastructure tests..."
	@$(MAKE) health
	@$(MAKE) validate

# Development helpers
dev-setup: ## Set up development environment
	@echo "🛠️  Setting up development environment..."
	@pip3 install -r requirements.txt || echo "⚠️  requirements.txt not found, install dependencies manually"
	@echo "📝 Copy terraform/terraform.tfvars.example to terraform/terraform.tfvars"
	@echo "🔑 Fill in your Proxmox credentials in terraform.tfvars"

clean: ## Clean temporary files
	@echo "🧹 Cleaning temporary files..."
	@find . -name "*.pyc" -delete
	@find . -name "__pycache__" -delete
	@rm -rf .terraform.lock.hcl

# Documentation
docs: ## Generate documentation
	@echo "📚 Documentation available in:"
	@echo "  - README.md"
	@echo "  - CLAUDE.md (for Claude Code)"
	@echo "  - docs/ directory"

# Quick start workflow
quickstart: ## Quick start workflow (discover -> import -> sync)
	@echo "🚀 Quick start workflow"
	@echo "======================="
	@$(MAKE) discover
	@$(MAKE) import
	@$(MAKE) sync
	@echo ""
	@echo "✅ Quick start complete!"
	@echo "📝 Next steps:"
	@echo "  1. Review generated configs in terraform/imported/"
	@echo "  2. Run 'make terraform-plan' to check for drift"
	@echo "  3. Run 'make health' to verify everything is working"