# Pro-Mata Infrastructure Makefile
# dev environment = Azure | prod environment = AWS

.DEFAULT_GOAL := help
.PHONY: help

# ============================================================================
# VARIABLES
# ============================================================================
ENV ?= prod
AWS_REGION ?= sa-east-1
AZURE_REGION ?= brazilsouth
INSTANCE_COUNT ?= 1
ENABLE_CLOUDFLARE ?= true

# Paths (relative to infrastructure directory)
ENV_DIR := envs/$(ENV)
ANSIBLE_DIR := cac

# Cloud provider paths
AZURE_TF_DIR := iac/azure
AWS_TF_DIR := iac/aws

# Dynamic TF directory based on environment
TF_DIR := $(if $(filter prod,$(ENV)),$(AWS_TF_DIR),$(AZURE_TF_DIR)/dev)
CLOUD := $(if $(filter prod,$(ENV)),AWS,Azure)

# Deployment mode based on instance count
DEPLOY_MODE := $(if $(filter 1,$(INSTANCE_COUNT)),Compose,Swarm)

# ============================================================================
# HELP
# ============================================================================
help: ## Show this help message
	@echo "🏗️  Pro-Mata Infrastructure Makefile"
	@echo "====================================="
	@echo "dev = Azure | prod = AWS"
	@echo "INSTANCE_COUNT=1 → Docker Compose | INSTANCE_COUNT=2+ → Docker Swarm"
	@echo ""
	@echo "📋 Available Commands:"
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
	@echo "💡 Examples:"
	@echo "  make tf-apply ENV=prod INSTANCE_COUNT=1   # AWS + Compose"
	@echo "  make tf-apply ENV=prod INSTANCE_COUNT=2   # AWS + Swarm"
	@echo "  make tf-apply ENV=dev INSTANCE_COUNT=1    # Azure + Compose"
	@echo "  make tf-apply ENV=dev INSTANCE_COUNT=2    # Azure + Swarm"

check-env:
	@if [ ! -d "$(ENV_DIR)" ]; then \
		echo "❌ Environment $(ENV) not found in $(ENV_DIR)"; \
		exit 1; \
	fi

# ============================================================================
# CORE DEPLOYMENT
# ============================================================================
tf-init: ## Initialize Terraform
	@echo "🚀 Initializing Terraform for $(ENV) ($(CLOUD))..."
	@cd $(TF_DIR) && terraform init

tf-plan: ## Plan Terraform changes
	@echo "📋 Planning Terraform for $(ENV) ($(CLOUD)) - $(DEPLOY_MODE) mode ($(INSTANCE_COUNT) instance(s))..."
	@echo "   Cloudflare DNS: $(ENABLE_CLOUDFLARE)"
	@cd $(TF_DIR) && (terraform init -input=false > /dev/null 2>&1 || terraform init)
	@cd $(TF_DIR) && terraform plan \
		-var="instance_count=$(INSTANCE_COUNT)" \
		-var="enable_cloudflare=$(ENABLE_CLOUDFLARE)"

tf-apply: ## Apply Terraform changes
	@echo "🚀 Applying Terraform for $(ENV) ($(CLOUD)) - $(DEPLOY_MODE) mode ($(INSTANCE_COUNT) instance(s))..."
	@echo "   Cloudflare DNS: $(ENABLE_CLOUDFLARE)"
	@cd $(TF_DIR) && (terraform init -input=false > /dev/null 2>&1 || terraform init)
	@cd $(TF_DIR) && terraform apply \
		-var="instance_count=$(INSTANCE_COUNT)" \
		-var="enable_cloudflare=$(ENABLE_CLOUDFLARE)" \
		-auto-approve

tf-destroy: ## Destroy infrastructure
	@echo "💥 WARNING: Destroying $(ENV) ($(CLOUD)) infrastructure ($(INSTANCE_COUNT) instance(s))!"
	@read -p "Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@cd $(TF_DIR) && terraform destroy \
		-var="instance_count=$(INSTANCE_COUNT)" \
		-var="enable_cloudflare=$(ENABLE_CLOUDFLARE)" \
		-auto-approve

deploy-ansible: check-env ## Deploy Ansible stack
	@echo "🔧 Deploying Ansible for $(ENV) ($(CLOUD))..."
	@PLAYBOOK=$(if $(filter prod,$(ENV)),$(ANSIBLE_DIR)/playbooks/deploy-prod-stack.yml,$(ANSIBLE_DIR)/playbooks/deploy-complete-stack.yml); \
	if [ -f envs/$(ENV)/secrets/vault.yml ] && [ -f .vault_password ]; then \
		./scripts/vault/export-env.sh $(ENV) file; \
		./scripts/vault/export-env.sh $(ENV) yaml; \
		./scripts/backup/backup-env-files.sh $(ENV); \
		ansible-playbook -i $(ENV_DIR)/hosts.yml \
			--vault-password-file .vault_pass \
			--extra-vars "env=$(ENV)" \
			--extra-vars "@.env.$(ENV).yml" \
			$$PLAYBOOK; \
	else \
		echo "⚠️  Vault not configured, deploying without vault secrets..."; \
		ansible-playbook -i $(ENV_DIR)/hosts.yml \
			--extra-vars "env=$(ENV)" \
			$$PLAYBOOK; \
	fi

deploy-full: check-env ## Complete deployment (Terraform → SSH → Inventory → Ansible)
	@echo "🚀 Complete deployment for $(ENV) ($(CLOUD))..."
	@$(MAKE) tf-apply ENV=$(ENV)
	@$(MAKE) extract-ssh-keys ENV=$(ENV)
	@$(MAKE) generate-inventory ENV=$(ENV)
	@$(MAKE) deploy-ansible ENV=$(ENV)
	@echo "✅ Deployment complete!"

deploy-compose: ## Deploy Docker Compose stack to single EC2 instance
	@echo "🐳 Deploying Docker Compose stack to $(ENV)..."
	@$(eval INSTANCE_IP := $(shell cd $(TF_DIR) && terraform output -raw instance_public_ip 2>/dev/null))
	@$(eval S3_BUCKET := $(shell cd $(TF_DIR) && terraform output -raw static_assets_bucket 2>/dev/null))
	@if [ -z "$(INSTANCE_IP)" ]; then echo "❌ No instance IP found"; exit 1; fi
	@echo "📦 Copying files to $(INSTANCE_IP)..."
	@scp -i envs/$(ENV)/.ssh/id_rsa -o StrictHostKeyChecking=no docker-compose.yml ubuntu@$(INSTANCE_IP):/opt/promata/
	@scp -i envs/$(ENV)/.ssh/id_rsa -r docker/configs/nginx ubuntu@$(INSTANCE_IP):/opt/promata/docker/configs/ || true
	@scp -i envs/$(ENV)/.ssh/id_rsa -r docker/database/scripts ubuntu@$(INSTANCE_IP):/opt/promata/docker/database/ || true
	@echo "📝 Creating .env file..."
	@ssh -i envs/$(ENV)/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$(INSTANCE_IP) \
		"cd /opt/promata && cat > .env << 'EOF'\n\
DOMAIN_NAME=$(DOMAIN_NAME)\n\
S3_BUCKET_NAME=$(S3_BUCKET)\n\
AWS_REGION=$(AWS_REGION)\n\
POSTGRES_DB=promata\n\
POSTGRES_USER=promata\n\
POSTGRES_PASSWORD=$$(openssl rand -base64 32)\n\
NODE_ENV=production\n\
JWT_SECRET=$$(openssl rand -base64 32)\n\
JWT_EXPIRES_IN=2h\n\
BACKEND_IMAGE=$(BACKEND_IMAGE)\n\
APP_SECRET=$$(openssl rand -base64 32)\n\
UMAMI_WEBSITE_ID=\n\
ACME_EMAIL=$(ACME_EMAIL)\n\
TRAEFIK_LOG_LEVEL=INFO\n\
CLOUDFLARE_API_TOKEN=$(CLOUDFLARE_API_TOKEN)\n\
EOF"
	@echo "🚀 Starting Docker Compose..."
	@ssh -i envs/$(ENV)/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$(INSTANCE_IP) \
		"cd /opt/promata && docker compose up -d"
	@echo "✅ Docker Compose deployed!"
	@echo "⏳ Waiting 30s for services to start..."
	@sleep 30
	@ssh -i envs/$(ENV)/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$(INSTANCE_IP) \
		"cd /opt/promata && docker compose ps"

deploy-compose-full: ## Complete deployment with Docker Compose (IaC + CaC)
	@echo "🚀 Complete Docker Compose deployment for $(ENV)..."
	@$(MAKE) tf-apply ENV=$(ENV) INSTANCE_COUNT=1
	@$(MAKE) extract-ssh-keys ENV=$(ENV)
	@$(MAKE) deploy-compose ENV=$(ENV)
	@echo "✅ Complete deployment finished!"
	@echo ""
	@echo "🌐 Services available at:"
	@echo "   - Frontend: https://$(DOMAIN_NAME)"
	@echo "   - API: https://api.$(DOMAIN_NAME)/health"
	@echo "   - Analytics: https://analytics.$(DOMAIN_NAME)"
	@echo "   - Metabase: https://metabase.$(DOMAIN_NAME)"
	@echo "   - Traefik: https://traefik.$(DOMAIN_NAME)"
	@echo ""
	@echo "⚠️  Note: First SSL certificate generation may take 1-2 minutes"

# ============================================================================
# VALIDATION & MONITORING
# ============================================================================
validate: check-env ## Validate infrastructure
	@echo "🔍 Validating $(ENV) ($(CLOUD))..."
	@cd $(TF_DIR) && terraform fmt -check && terraform validate
	@./scripts/utils/validate-infrastructure.sh $(ENV)

health: check-env ## Health check
	@echo "🏥 Health check for $(ENV) ($(CLOUD))..."
	@./scripts/utils/health-check.sh $(ENV)

status: check-env ## Show status
	@echo "📊 Status for $(ENV) ($(CLOUD))..."
	@cd $(TF_DIR) && terraform output 2>/dev/null || echo "No outputs"
	@docker service ls 2>/dev/null | grep promata || echo "No services"

outputs: ## Show Terraform outputs
	@cd $(TF_DIR) && terraform output

# ============================================================================
# SSH MANAGEMENT
# ============================================================================
extract-ssh-keys: ## Extract SSH keys from Terraform
	@echo "🔑 Extracting SSH keys for $(ENV)..."
	@mkdir -p envs/$(ENV)/.ssh
	@cd $(TF_DIR) && \
	if terraform output ssh_private_key > /dev/null 2>&1; then \
		terraform output -raw ssh_private_key > ../../envs/$(ENV)/.ssh/id_rsa; \
		chmod 600 ../../envs/$(ENV)/.ssh/id_rsa; \
		terraform output -raw ssh_public_key > ../../envs/$(ENV)/.ssh/id_rsa.pub; \
		chmod 644 ../../envs/$(ENV)/.ssh/id_rsa.pub; \
		echo "✅ SSH keys extracted to envs/$(ENV)/.ssh/"; \
	fi

ssh-instance: ## SSH to instance
	@$(eval INSTANCE_IP := $(shell cd $(TF_DIR) && terraform output -raw instance_public_ip 2>/dev/null))
	@ssh -i envs/$(ENV)/.ssh/id_rsa ubuntu@$(INSTANCE_IP)

generate-inventory: check-env ## Generate Ansible inventory from Terraform
	@echo "📝 Generating Ansible inventory for $(ENV)..."
	@cd $(TF_DIR) && \
	INSTANCE_IP=$$(terraform output -raw instance_public_ip 2>/dev/null); \
	PRIVATE_IP=$$(terraform output -raw instance_private_ip 2>/dev/null); \
	if [ -n "$$INSTANCE_IP" ]; then \
		sed -i "s/manager_public_ip: .*/manager_public_ip: $$INSTANCE_IP/" ../../envs/$(ENV)/hosts.yml; \
		sed -i "s/manager_private_ip: .*/manager_private_ip: $$PRIVATE_IP/" ../../envs/$(ENV)/hosts.yml; \
		sed -i "s/ansible_host: .*/ansible_host: $$INSTANCE_IP/" ../../envs/$(ENV)/hosts.yml; \
		sed -i "s/private_ip: .*/private_ip: $$PRIVATE_IP/" ../../envs/$(ENV)/hosts.yml; \
		echo "✅ Inventory updated with IP: $$INSTANCE_IP"; \
	else \
		echo "❌ Could not get instance IP from Terraform"; \
		exit 1; \
	fi

# ============================================================================
# VAULT & SECRETS
# ============================================================================
vault-setup: ## Setup Ansible Vault
	@./scripts/vault/vault-easy.sh setup

vault-edit: check-env ## Edit environment secrets
	@./scripts/vault/vault-easy.sh edit envs/$(ENV)/secrets/vault.yml

vault-view: check-env ## View environment secrets
	@./scripts/vault/vault-easy.sh view envs/$(ENV)/secrets/vault.yml

# ============================================================================
# BACKUP & CLEANUP
# ============================================================================
backup-env: check-env ## Backup environment files
	@echo "💾 Backing up $(ENV) environment files..."
	@./scripts/vault/export-env.sh $(ENV) file
	@./scripts/vault/export-env.sh $(ENV) yaml
	@./scripts/backup/backup-env-files.sh $(ENV)

backup-tf: check-env ## Backup Terraform state
	@echo "💾 Backing up Terraform state for $(ENV)..."
	@./scripts/backup/backup-terraform-state.sh $(ENV)

backup-db: check-env ## Backup database
	@echo "💾 Backing up database for $(ENV)..."
	@./scripts/backup/backup-database.sh $(ENV)

clean: ## Clean temporary files
	@echo "🧹 Cleaning..."
	@find . -name "*.tmp" -delete
	@find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "terraform.tfstate.backup" -delete
	@find . -name ".terraform.lock.hcl" -delete

reset-db: check-env ## Reset database (removes volumes)
	@echo "🔄 WARNING: This removes all data for $(ENV)!"
	@read -p "Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@docker stack rm promata-$(ENV) 2>/dev/null || true
	@sleep 15
	@docker volume ls | grep promata-$(ENV) | awk '{print $$2}' | xargs -r docker volume rm
	@echo "✅ Database reset"

# ============================================================================
# AWS-SPECIFIC (Production)
# ============================================================================
aws-setup-backend: ## Setup S3 backend (run once)
	@echo "🏗️  Setting up AWS backend..."
	@cd iac/aws/setup && terraform init && terraform apply

aws-logs: ## Show CloudWatch logs
	@aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/promata-$(ENV)" --region $(AWS_REGION)

# ============================================================================
# AZURE-SPECIFIC (Development)
# ============================================================================
azure-setup-backend: ## Setup Azure backend for Terraform state (run once)
	@echo "🏗️  Setting up Azure backend for Terraform state..."
	@az group create --name rg-promata-terraform-state --location eastus --output table
	@az storage account create \
		--name stpromatastate \
		--resource-group rg-promata-terraform-state \
		--location eastus \
		--sku Standard_LRS \
		--output table
	@az storage container create \
		--name tfstate \
		--account-name stpromatastate \
		--output table
	@echo "✅ Azure backend setup complete!"

import-ips: check-env ## Import Azure IPs to Terraform
	@echo "🔒 Importing IPs for $(ENV)..."
	@./scripts/iac/import-existing-ips.sh $(ENV)

# ============================================================================
# MAINTENANCE
# ============================================================================
fmt: ## Format Terraform files
	@echo "🎨 Formatting..."
	@terraform fmt -recursive

# ============================================================================
# SHORTCUTS
# ============================================================================
dev: ## Quick dev deployment
	@$(MAKE) deploy-full ENV=dev

prod: ## Quick prod deployment
	@$(MAKE) deploy-full ENV=prod

# ============================================================================
# LOCAL DEVELOPMENT (No Cloud)
# ============================================================================
local: ## Run complete stack locally with Docker Compose
	@echo "🐳 Starting Pro-Mata stack locally..."
	@$(MAKE) local-setup
	@$(MAKE) local-up
	@echo ""
	@echo "✅ Stack running locally!"
	@echo ""
	@echo "🌐 Services available at:"
	@echo "   - Frontend: http://localhost"
	@echo "   - API: http://localhost:3000/health"
	@echo "   - Traefik Dashboard: http://localhost:8080"
	@echo "   - PostgreSQL: localhost:5432"
	@echo ""
	@echo "📝 Commands:"
	@echo "   make local-logs    - View logs"
	@echo "   make local-ps      - Container status"
	@echo "   make local-down    - Stop stack"
	@echo "   make local-reset   - Reset everything (including data)"

local-setup: ## Setup local environment
	@echo "📁 Setting up local environment..."
	@mkdir -p docker/configs/traefik docker/configs/nginx docker/database/scripts/init
	@# Create local .env if not exists
	@if [ ! -f .env ]; then \
		echo "Creating .env from local.env.example..."; \
		cp envs/local.env.example .env 2>/dev/null || \
		cat > .env << 'EOF'
# Pro-Mata Local Development
ENVIRONMENT=local
PROJECT_NAME=promata
DOMAIN_NAME=localhost

# Database
POSTGRES_DB=promata
POSTGRES_USER=promata
POSTGRES_PASSWORD=localdev123

# Application
JWT_SECRET=local-dev-jwt-secret-change-in-production
APP_SECRET=local-dev-app-secret-change-in-production
DATABASE_URL=postgresql://promata:localdev123@postgres:5432/promata?schema=app

# AWS S3 (leave empty for local, uses mock/disabled)
AWS_REGION=sa-east-1
AWS_S3_BUCKET=
S3_BUCKET_NAME=

# Traefik
TRAEFIK_LOG_LEVEL=DEBUG
CLOUDFLARE_API_TOKEN=

# Backend
BACKEND_IMAGE=norohim/pro-mata-backend:latest
EOF
	fi
	@# Create traefik config for local (HTTP only, no SSL)
	@cat > docker/configs/traefik/traefik.yml << 'EOF'
api:
  dashboard: true
  insecure: true

entryPoints:
  web:
    address: ":80"
  websecure:
    address: ":443"

providers:
  docker:
    endpoint: "unix:///var/run/docker.sock"
    exposedByDefault: false

log:
  level: DEBUG
EOF
	@# Create database init script
	@cat > docker/database/scripts/init/01-create-schemas.sh << 'EOF'
#!/bin/bash
set -e
psql -v ON_ERROR_STOP=1 --username "$$POSTGRES_USER" --dbname "$$POSTGRES_DB" <<-EOSQL
    CREATE SCHEMA IF NOT EXISTS app;
    CREATE SCHEMA IF NOT EXISTS umami;
    CREATE SCHEMA IF NOT EXISTS metabase;
    ALTER DATABASE promata SET search_path TO app,public;
    GRANT ALL PRIVILEGES ON SCHEMA app TO $$POSTGRES_USER;
    GRANT ALL PRIVILEGES ON SCHEMA umami TO $$POSTGRES_USER;
    GRANT ALL PRIVILEGES ON SCHEMA metabase TO $$POSTGRES_USER;
EOSQL
echo "✅ Database schemas initialized!"
EOF
	@chmod +x docker/database/scripts/init/01-create-schemas.sh
	@echo "✅ Local environment ready!"

local-up: ## Start local stack
	@echo "🚀 Starting containers..."
	@docker compose up -d
	@echo "⏳ Waiting for services to start..."
	@sleep 10
	@# Create schemas if postgres is fresh
	@docker exec -i promata-postgres psql -U promata -d promata -c "CREATE SCHEMA IF NOT EXISTS app; CREATE SCHEMA IF NOT EXISTS umami; CREATE SCHEMA IF NOT EXISTS metabase;" 2>/dev/null || true
	@# Wait for backend
	@echo "⏳ Waiting for backend..."
	@for i in 1 2 3 4 5 6 7 8 9 10; do \
		if curl -s http://localhost:3000/health > /dev/null 2>&1; then \
			echo "✅ Backend is ready!"; \
			break; \
		fi; \
		sleep 3; \
	done
	@docker compose ps

local-down: ## Stop local stack
	@echo "🛑 Stopping containers..."
	@docker compose down
	@echo "✅ Stack stopped"

local-logs: ## View local logs
	@docker compose logs -f

local-ps: ## Show local container status
	@docker compose ps

local-reset: ## Reset local environment (removes all data!)
	@echo "⚠️  WARNING: This will remove ALL local data!"
	@read -p "Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ] || exit 1
	@docker compose down -v --remove-orphans
	@rm -f .env
	@rm -rf docker/configs/traefik/traefik.yml
	@echo "✅ Local environment reset"

local-db: ## Connect to local PostgreSQL
	@docker exec -it promata-postgres psql -U promata -d promata

local-backend-logs: ## View backend logs only
	@docker compose logs -f backend

local-rebuild: ## Rebuild and restart local stack
	@echo "🔄 Rebuilding local stack..."
	@docker compose down
	@docker compose pull
	@$(MAKE) local-up