# Pro-Mata Infrastructure Makefile - New Structure
# Updated for unified envs/ structure

.DEFAULT_GOAL := help
.PHONY: help init deploy validate backup clean

# Environment and paths
ENV ?= dev
ENV_DIR := envs/$(ENV)
TF_DIR := terraform/deployments/$(ENV)
ANSIBLE_DIR := ansible

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

deploy: check-env ## Deploy infrastructure
	@echo "🚀 Deploying $(ENV) environment..."
	@./scripts/deploy/deploy.sh $(ENV)

deploy-terraform: check-env ## Deploy only Terraform
	@echo "🏗️  Deploying Terraform for $(ENV)..."
	@cd $(TF_DIR) && terraform init -backend-config=../../backends/$(ENV).tf
	@cd $(TF_DIR) && terraform plan -var-file=../../../$(ENV_DIR)/terraform.tfvars
	@cd $(TF_DIR) && terraform apply -var-file=../../../$(ENV_DIR)/terraform.tfvars

deploy-ansible: check-env ## Deploy only Ansible
	@echo "🔧 Deploying Ansible for $(ENV)..."
	@ansible-playbook -i $(ANSIBLE_DIR)/inventory/$(ENV)/hosts.yml \
		-e @$(ENV_DIR)/ansible-vars.yml \
		--vault-password-file $(ENV_DIR)/secrets/.vault_pass \
		$(ANSIBLE_DIR)/playbooks/deploy.yml

validate: check-env ## Validate infrastructure
	@echo "🔍 Validating $(ENV) environment..."
	@./scripts/utils/validate-infrastructure.sh $(ENV)

validate-terraform: check-env ## Validate Terraform
	@echo "🔍 Validating Terraform for $(ENV)..."
	@cd $(TF_DIR) && terraform fmt -check
	@cd $(TF_DIR) && terraform validate

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

# Development commands
dev-init: ## Initialize development environment
	@$(MAKE) init ENV=dev

dev-deploy: ## Deploy development environment
	@$(MAKE) deploy ENV=dev

dev-validate: ## Validate development environment
	@$(MAKE) validate ENV=dev

# Production commands
prod-init: ## Initialize production environment
	@$(MAKE) init ENV=prod

prod-deploy: ## Deploy production environment
	@$(MAKE) deploy ENV=prod

prod-validate: ## Validate production environment
	@$(MAKE) validate ENV=prod

# Migration commands
migrate-structure: ## Migrate to new structure
	@echo "🔄 Migrating repository structure..."
	@./scripts/utils/migrate-structure.sh

validate-migration: ## Validate migration
	@echo "🔍 Validating migration..."
	@./scripts/utils/validate-migration.sh

