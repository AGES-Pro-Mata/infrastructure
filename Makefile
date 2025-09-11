# Pro-Mata Infrastructure Makefile - New Structure
# Updated for unified envs/ structure

.DEFAULT_GOAL := help
.PHONY: help init deploy validate backup clean

# Environment and paths
ENV ?= dev
ENV_DIR := envs/$(ENV)
TF_DIR := iac/deployments/$(ENV)
ANSIBLE_DIR := cac

# Check if environment exists
check-env:
	@if [ ! -d "$(ENV_DIR)" ]; then \
		echo "❌ Environment $(ENV) not found in $(ENV_DIR)"; \
		exit 1; \
	fi

help: ## Show this help message
	@echo "🏗️  Pro-Mata Infrastructure Makefile"
	@echo "====================================="
	@echo ""
	@echo "📋 Available Commands:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

init: check-env ## Initialize environment
	@echo "🔧 Initializing $(ENV) environment..."
	@./scripts/setup/init-environment.sh $(ENV)


deploy-terraform: check-env ## Deploy only Terraform
	@echo "🏗️  Deploying Terraform for $(ENV)..."
	@cd $(TF_DIR) && terraform init -backend-config=../../backends/$(ENV)-backend.hcl
	@cd $(TF_DIR) && terraform plan -var-file=terraform.tfvars
	@cd $(TF_DIR) && terraform apply -var-file=terraform.tfvars --auto-approve

deploy-ansible: check-env ## Deploy only Ansible stack
	@echo "🔧 Deploying Ansible for $(ENV) with complete stack..."
	@ansible-playbook -i $(ENV_DIR)/hosts.yml \
		--vault-password-file .vault_pass \
		--extra-vars "env=$(ENV)" \
		$(ANSIBLE_DIR)/playbooks/deploy-complete-stack.yml

validate: check-env ## Validate infrastructure
	@echo "🔍 Validating $(ENV) environment..."
	@./scripts/utils/validate-infrastructure.sh $(ENV)

validate-terraform: check-env ## Validate Terraform
	@echo "🔍 Validating Terraform for $(ENV)..."
	@if ! command -v terraform >/dev/null 2>&1; then \
		echo "⚠️  Terraform not found. Skipping validation."; \
		echo "💡 Install Terraform to run validation: https://terraform.io/downloads"; \
	else \
		cd $(TF_DIR) && terraform fmt -check; \
		cd $(TF_DIR) && terraform validate; \
	fi

backup: check-env ## Backup environment
	@echo "💾 Backing up $(ENV) environment..."
	@./scripts/backup/backup-all.sh $(ENV)

backup-terraform: check-env ## Backup Terraform state
	@echo "💾 Backing up Terraform state for $(ENV)..."
	@./scripts/backup/backup-terraform-state.sh $(ENV)

clean: ## Clean temporary files
	@echo "🧹 Cleaning temporary files..."
	@find . -name "*.tmp" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "terraform.tfstate.backup" -delete

clean-volumes: check-env ## Remove Docker volumes to force database reinitialization
	@echo "🗑️  WARNING: This will remove all data volumes for $(ENV) environment!"
	@echo "🔄 Database initialization scripts will run on next deployment"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@docker volume rm promata-$(ENV)_postgres_primary_data promata-$(ENV)_postgres_replica_data 2>/dev/null || true
	@docker volume rm promata-$(ENV)_postgres_config 2>/dev/null || true
	@docker volume rm promata-$(ENV)_grafana_data promata-$(ENV)_prometheus_data 2>/dev/null || true
	@docker volume rm promata-$(ENV)_metabase_data promata-$(ENV)_pgadmin_data 2>/dev/null || true
	@docker volume rm promata-$(ENV)_umami_db_data 2>/dev/null || true
	@echo "✅ Volumes cleaned. Database will reinitialize on next deployment."

reset-database: check-env ## Reset database completely (removes stack and volumes)
	@echo "🔄 Resetting database for $(ENV) environment..."
	@docker stack rm promata-$(ENV) 2>/dev/null || true
	@echo "⏳ Waiting for stack removal..."
	@sleep 15
	@$(MAKE) clean-volumes ENV=$(ENV)
	@echo "✅ Database reset complete. Ready for fresh deployment."

# Development commands
dev-init: ## Initialize development environment
	@$(MAKE) init ENV=dev

dev-deploy: ## Deploy development environment
	@$(MAKE) deploy ENV=dev

dev-deploy-full: ## Complete dev deployment: Terraform → Update vars → Ansible
	@$(MAKE) deploy-full ENV=dev

dev-validate: ## Validate development environment
	@$(MAKE) validate ENV=dev

# Migration commands
migrate-structure: ## Migrate to new structure
	@echo "🔄 Migrating repository structure..."
	@./scripts/utils/migrate-structure.sh

validate-migration: ## Validate migration
	@echo "🔍 Validating migration..."
	@./scripts/utils/validate-migration.sh

# CI/CD automation targets
deploy-automated: check-env ## Automated deployment for CI/CD with IP preservation
	@echo "🤖 Starting automated deployment for $(ENV) with IP preservation..."
	@echo "🔒 Step 1: Import existing IPs to Terraform state..."
	@./scripts/iac/import-existing-ips.sh $(ENV) || echo "⚠️  IPs might already be imported"
	@echo "🏗️  Step 2: Deploy infrastructure preserving IPs..."
	@$(MAKE) deploy-full ENV=$(ENV)
	@echo "✅ Automated deployment completed!"

# Multi-repo CI/CD integration
ci-cd-init: check-env ## Initialize CI/CD for multi-repo integration
	@echo "🔧 Initializing CI/CD integration for $(ENV)..."
	@./scripts/ci-cd/setup-shared-state.sh $(ENV)
	@./scripts/ci-cd/generate-workflow.sh $(ENV)

ci-cd-deploy: check-env ## Deploy via CI/CD pipeline
	@echo "🚀 CI/CD Pipeline deployment for $(ENV)..."
	@echo "📋 Using shared Terraform state and unified configs"
	@$(MAKE) deploy-automated ENV=$(ENV)

# Cleanup and maintenance
cleanup-deprecated: ## Remove deprecated files and clean repository
	@echo "🧹 Cleaning deprecated files..."
	@./scripts/cleanup/remove-deprecated-files.sh
	@./scripts/cleanup/cleanup-unused-envs.sh

maintenance: check-env ## Full maintenance cycle for environment
	@echo "🔧 Running maintenance for $(ENV)..."
	@$(MAKE) cleanup-deprecated
	@$(MAKE) validate ENV=$(ENV)
	@$(MAKE) backup ENV=$(ENV)

deploy-full: check-env ## Complete deployment: Terraform → Extract SSH → Update vars → Ansible
	@echo "🚀 Starting complete deployment for $(ENV)..."
	@echo "📋 Steps: 1) Terraform 2) Extract SSH keys 3) Update inventory/vars 4) Ansible"
	@echo ""
	@echo "🏗️  Step 1/4: Deploying Terraform infrastructure..."
	@$(MAKE) deploy-terraform ENV=$(ENV)
	@echo ""
	@echo "� Step 2/4: Extracting SSH keys from Terraform..."
	@$(MAKE) extract-ssh-keys ENV=$(ENV)
	@echo ""
	@echo "🔄 Step 3/4: Updating Ansible inventory from Terraform outputs..."
	@$(MAKE) update-inventory ENV=$(ENV)
	@echo ""
	@echo "🔧 Step 4/4: Deploying application stack with Ansible..."
	@$(MAKE) deploy-ansible ENV=$(ENV)
	@echo ""
	@echo "✅ Complete deployment finished for $(ENV)!"
	@$(MAKE) show-deployment-info ENV=$(ENV)

update-inventory: check-env ## Update Ansible inventory from Terraform outputs
	@echo "🔄 Updating Ansible inventory for $(ENV) from Terraform outputs..."
	@cd $(TF_DIR) && \
	if terraform output > /dev/null 2>&1; then \
		echo "📊 Extracting Terraform outputs..."; \
		MANAGER_IP=$$(terraform output -raw swarm_manager_public_ip 2>/dev/null || echo ""); \
		WORKER_IP=$$(terraform output -raw swarm_worker_public_ip 2>/dev/null || echo ""); \
		MANAGER_PRIVATE_IP=$$(terraform output -raw swarm_manager_private_ip 2>/dev/null || echo ""); \
		WORKER_PRIVATE_IP=$$(terraform output -raw swarm_worker_private_ip 2>/dev/null || echo ""); \
		DOMAIN_NAME=$$(terraform output -raw domain_name 2>/dev/null || echo "promata.com.br"); \
		if [ -n "$$MANAGER_IP" ] && [ -n "$$WORKER_IP" ]; then \
			echo "🔧 Updating inventory file..."; \
			mkdir -p ../../../$(ANSIBLE_DIR)/inventory/$(ENV); \
			echo "# Generated Ansible Inventory for Pro-Mata $(ENV) Environment" > ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "# Auto-generated from Terraform outputs - do not edit manually" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "# Generated: $$(date)" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "---" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "all:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "  vars:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    ansible_user: ubuntu" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    ansible_ssh_private_key_file: \"$$(realpath ../../../.ssh/dev_private_key)\"" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    ansible_ssh_common_args: '-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    env: $(ENV)" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    domain_name: \"$$DOMAIN_NAME\"" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    manager_public_ip: \"$$MANAGER_IP\"" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    manager_private_ip: \"$$MANAGER_PRIVATE_IP\"" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    worker_public_ip: \"$$WORKER_IP\"" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    worker_private_ip: \"$$WORKER_PRIVATE_IP\"" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "  children:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    promata_$(ENV):" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "      children:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "        managers:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "          hosts:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "            swarm-manager:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "              ansible_host: $$MANAGER_IP" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "              private_ip: $$MANAGER_PRIVATE_IP" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "              node_role: manager" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "        workers:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "          hosts:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "            swarm-worker-1:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "              ansible_host: $$WORKER_IP" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "              private_ip: $$WORKER_PRIVATE_IP" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "              node_role: worker" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    # Convenience groups for easier targeting" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    swarm_managers:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "      hosts:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "        swarm-manager:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    swarm_workers:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "      hosts:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "        swarm-worker-1:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "    swarm_nodes:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "      children:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "        swarm_managers:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "        swarm_workers:" >> ../../../$(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml; \
			echo "✅ Inventory updated with IPs: Manager=$$MANAGER_IP, Worker=$$WORKER_IP"; \
		else \
			echo "❌ Failed to get VM IPs from Terraform output"; \
			exit 1; \
		fi; \
	else \
		echo "❌ No Terraform outputs found. Run 'make deploy-terraform ENV=$(ENV)' first"; \
		exit 1; \
	fi

extract-ssh-keys: check-env ## Extract SSH keys from Terraform and setup access
	@echo "🔑 Extracting SSH keys from Terraform for $(ENV)..."
	@cd $(TF_DIR) && \
	if terraform output ssh_private_key > /dev/null 2>&1; then \
		echo "📄 Extracting SSH private key..."; \
		mkdir -p ../../../.ssh; \
		terraform output -raw ssh_private_key > ../../../.ssh/dev_private_key; \
		chmod 600 ../../../.ssh/dev_private_key; \
		echo "📄 Extracting SSH public key..."; \
		terraform output -raw ssh_public_key > ../../../.ssh/dev_private_key.pub; \
		chmod 644 ../../../.ssh/dev_private_key.pub; \
		echo "✅ SSH keys extracted to .ssh/"; \
	else \
		echo "❌ SSH keys not found in Terraform output"; \
		exit 1; \
	fi

stacks-deploy: check-env ## Deploy only application stacks
	@echo "📦 Deploying dev-complete stack for $(ENV)..."
	@ansible-playbook -i $(ENV_DIR)/hosts.yml \
		--vault-password-file .vault_pass \
		--extra-vars "env=$(ENV)" \
		$(ANSIBLE_DIR)/playbooks/deploy-complete-stack.yml

health: check-env ## Health check for environment
	@echo "🏥 Running health checks for $(ENV)..."
	@./scripts/utils/health-check.sh $(ENV)

status: check-env ## Show environment status
	@echo "📊 Showing status for $(ENV)..."
	@./scripts/utils/test-infrastructure.sh $(ENV)

show-deployment-info: check-env ## Show deployment information
	@echo "📋 Deployment information for $(ENV):"
	@echo "Environment: $(ENV)"
	@echo "TF Directory: $(TF_DIR)" 
	@echo "Env Directory: $(ENV_DIR)"
	@if [ -d "$(TF_DIR)" ]; then \
		cd $(TF_DIR) && terraform output 2>/dev/null || echo "No Terraform outputs available"; \
	fi

update-dev: check-env ## Update development environment
	@echo "🔄 Updating $(ENV) environment with complete stack..."
	@ansible-playbook -i $(ENV_DIR)/hosts.yml \
		--vault-password-file .vault_pass \
		--extra-vars "env=$(ENV)" \
		$(ANSIBLE_DIR)/playbooks/deploy-complete-stack.yml

destroy-dev: ## Destroy development infrastructure
	@echo "💥 Destroying dev infrastructure..."
	@cd iac/deployments/dev && terraform destroy -var-file=../../../envs/dev/config.yml --auto-approve


ssh-setup: check-env ## Setup SSH access for environment
	@echo "🔑 Setting up SSH access for $(ENV)..."
	@if [ -f "ssh-keys/setup-ssh.sh" ]; then \
		source ssh-keys/setup-ssh.sh; \
	else \
		echo "❌ SSH setup script not found. Run deployment first."; \
		exit 1; \
	fi

ssh-extract: check-env ## Extract SSH keys from deployed infrastructure
	@echo "🔑 Extracting SSH keys for $(ENV)..."
	@./scripts/setup/setup-ssh.sh $(ENV)

ssh-info: check-env ## Show SSH connection information
	@echo "🔑 SSH Connection Information for $(ENV):"
	@echo "========================================"
	@if [ -f "ssh-keys/ssh-config" ]; then \
		echo "SSH Config file: ssh-keys/ssh-config"; \
		echo ""; \
		echo "Available hosts:"; \
		grep "^Host " ssh-keys/ssh-config | sed 's/Host //'; \
		echo ""; \
		echo "Usage examples:"; \
		echo "  ssh -F ssh-keys/ssh-config manager-$(ENV)"; \
		echo "  ssh -F ssh-keys/ssh-config worker-$(ENV)"; \
		echo "  ssh -F ssh-keys/ssh-config swarm-$(ENV)"; \
	else \
		echo "❌ SSH config not found. Run deployment first."; \
	fi

ssh-keys: check-env ## Show SSH keys location
	@echo "� SSH Keys for $(ENV):"
	@echo "======================"
	@if [ -d "ssh-keys" ]; then \
		ls -la ssh-keys/; \
		echo ""; \
		echo "Private key: ssh-keys/$(ENV)-ssh-key"; \
		echo "Public key:  ssh-keys/$(ENV)-ssh-key.pub"; \
		echo "SSH config:  ssh-keys/ssh-config"; \
		echo "Setup script: ssh-keys/setup-ssh.sh"; \
	else \
		echo "❌ SSH keys directory not found. Run deployment first."; \
	fi

ssh-test: check-env ## Test SSH connections to VMs
	@echo "🧪 Testing SSH connections for $(ENV)..."
	@if [ -f "ssh-keys/ssh-config" ]; then \
		echo "Testing manager connection..."; \
		ssh -F ssh-keys/ssh-config -o ConnectTimeout=10 manager-$(ENV) "echo '✅ Manager VM: OK' && uptime" 2>/dev/null || echo "❌ Manager VM: Failed"; \
		echo ""; \
		echo "Testing worker connection..."; \
		ssh -F ssh-keys/ssh-config -o ConnectTimeout=10 worker-$(ENV) "echo '✅ Worker VM: OK' && uptime" 2>/dev/null || echo "❌ Worker VM: Failed"; \
	else \
		echo "❌ SSH config not found. Run deployment first."; \
	fi

# === SECRETS & VAULT MANAGEMENT ===
vault-setup: ## Setup Ansible Vault (first time only)
	@echo "🔐 Setting up Ansible Vault..."
	@./scripts/vault/vault-easy.sh setup

vault-init-dev: ## Initialize dev environment secrets
	@./scripts/vault/vault-easy.sh init-dev

vault-edit-dev: ## Edit dev environment secrets
	@./scripts/vault/vault-easy.sh edit envs/dev/secrets/vault.yml

vault-view-dev: ## View dev environment secrets
	@./scripts/vault/vault-easy.sh view envs/dev/secrets/vault.yml

# === IP MANAGEMENT ===
import-ips: check-env ## Import existing Azure IPs to Terraform state
	@echo "🔒 Importing existing IPs for $(ENV)..."
	@./scripts/iac/import-existing-ips.sh $(ENV)

# === QUICK COMMANDS ===  
quick-dev: ## Quick dev deployment (preserves IPs)
	@$(MAKE) import-ips ENV=dev
	@$(MAKE) deploy-automated ENV=dev

quick-status: check-env ## Quick status check
	@echo "📊 Quick status for $(ENV):"
	@echo "Environment: $(ENV)"
	@if [ -d "$(TF_DIR)" ]; then cd $(TF_DIR) && terraform output 2>/dev/null | head -10 || echo "No Terraform outputs"; fi
	@echo "Docker services:" && docker service ls 2>/dev/null | grep promata || echo "No services running"

