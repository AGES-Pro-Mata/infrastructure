# Pro-Mata Infrastructure Automation
.PHONY: help init deploy-dev update-dev destroy-dev status logs

ENV ?= dev
SERVICE ?= all
STACK_DIR = docker/stacks
SCRIPT_DIR = scripts

help:
	@echo "🏗️  Pro-Mata Infrastructure Commands"
	@echo ""
	@echo "🚀 Main Commands:"
	@echo "  init                    Initialize complete infrastructure"
	@echo "  deploy-dev              Deploy dev environment (complete)"
	@echo "  update-dev              Update services"
	@echo "  destroy-dev             Destroy dev environment"
	@echo "  status                  Show infrastructure status"
	@echo ""
	@echo "🔧 Component Commands:"
	@echo "  terraform-init          Initialize Terraform"
	@echo "  terraform-plan          Plan Terraform changes"
	@echo "  terraform-apply         Apply Terraform changes"
	@echo "  swarm-init              Initialize Docker Swarm"
	@echo "  ansible-configure       Configure with Ansible"
	@echo "  stacks-deploy           Deploy all stacks"
	@echo "  dns-update              Update DuckDNS"
	@echo ""
	@echo "📊 Monitoring & Maintenance:"
	@echo "  health                  Health check"
	@echo "  logs SERVICE=name       Show service logs"
	@echo "  backup                  Backup database"
	@echo "  rollback                Emergency rollback"
	@echo ""
	@echo "🔒 Security Commands:"
	@echo "  security-setup          Setup Azure Key Vault + secrets"
	@echo "  security-load           Load secrets for development"
	@echo "  security-rotate         Rotate all secrets"
	@echo "  security-audit          Security audit"
	@echo ""
	@echo "🔧 Development Commands:"
	@echo "  update SERVICE=name     Update specific service"
	@echo "  shell                   SSH to swarm manager"
	@echo "  cleanup                 Clean unused resources"

# Initialize complete infrastructure
init: terraform-init

# Complete deployment pipeline
deploy-dev: terraform-apply swarm-init ansible-configure stacks-deploy dns-update health
	@echo "✅ Complete dev environment deployed!"
	@echo "🌐 Frontend: https://$(shell cd environments/$(ENV) && grep DOMAIN_NAME .env.$(ENV) | cut -d= -f2)"
	@echo "🔧 API: https://api.$(shell cd environments/$(ENV) && grep DOMAIN_NAME .env.$(ENV) | cut -d= -f2)"

# Update existing deployment
update-dev:
	@$(SCRIPT_DIR)/update-stacks.sh $(ENV) $(SERVICE)

# Terraform commands
terraform-init:
	@echo "🏗️  Initializing Terraform with Azure Backend..."
	@if [ ! -f "terraform/environments/$(ENV)/backend.tf" ]; then \
		echo "Setting up Azure Backend for Terraform state..."; \
		chmod +x terraform/backend-setup.sh && terraform/backend-setup.sh; \
	fi
	@cd terraform/environments/$(ENV) && terraform init

terraform-plan:
	@echo "📋 Planning Terraform changes..."
	@cd terraform/environments/$(ENV) && terraform plan -var-file="../../../environments/$(ENV)/terraform.tfvars"

terraform-apply: terraform-plan
	@echo "🚀 Applying Terraform changes..."
	@cd terraform/environments/$(ENV) && terraform apply -var-file="../../../environments/$(ENV)/terraform.tfvars" -auto-approve

terraform-destroy:
	@echo "💥 Destroying infrastructure..."
	@cd terraform/environments/$(ENV) && terraform destroy -var-file="../../../environments/$(ENV)/terraform.tfvars" -auto-approve

# Docker Swarm commands
swarm-init:
	@echo "🐳 Initializing Docker Swarm..."
	@$(SCRIPT_DIR)/swarm-init.sh $(ENV)

# Ansible commands
ansible-configure:
	@echo "🔧 Configuring with Ansible..."
	@cd ansible && ansible-playbook -i inventory/$(ENV)/hosts.yml playbooks/site.yml

# Stack deployment
stacks-deploy:
	@echo "📦 Deploying stacks..."
	@$(SCRIPT_DIR)/deploy-stacks.sh $(ENV)

stacks-update:
	@echo "🔄 Updating stacks..."
	@$(SCRIPT_DIR)/update-stacks.sh $(ENV) $(SERVICE)

stacks-destroy:
	@echo "🗑️  Removing stacks..."
	@docker stack rm promata-proxy promata-app promata-database || true

# DNS and network
dns-update:
	@echo "🌐 Updating DNS..."
	@$(SCRIPT_DIR)/duckdns-updater.sh $(ENV)

networks-create:
	@echo "🌐 Creating Docker networks..."
	@docker network create --driver overlay --attachable promata_public || true
	@docker network create --driver overlay --attachable promata_internal || true  
	@docker network create --driver overlay --attachable promata_database || true

# Monitoring and maintenance
status:
	@echo "📊 Infrastructure Status:"
	@echo ""
	@if docker node ls >/dev/null 2>&1; then \
		echo "🐳 Docker Swarm:"; \
		docker node ls; \
		echo ""; \
		echo "📦 Services:"; \
		docker service ls; \
	else \
		echo "❌ Docker Swarm not initialized or not accessible"; \
	fi

health:
	@echo "🏥 Running health check..."
	@$(SCRIPT_DIR)/health-check.sh $(ENV)

logs:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ Usage: make logs SERVICE=service-name"; \
		echo "Available services:"; \
		docker service ls --format "{{.Name}}"; \
	else \
		docker service logs -f --tail 100 $(SERVICE); \
	fi

# Database operations
backup:
	@echo "💾 Creating database backup..."
	@$(SCRIPT_DIR)/backup-database.sh $(ENV)

restore:
	@if [ -z "$(BACKUP_FILE)" ]; then \
		echo "❌ Usage: make restore BACKUP_FILE=filename.sql.gz"; \
	else \
		echo "♻️  Restoring database from $(BACKUP_FILE)..."; \
		$(SCRIPT_DIR)/restore-database.sh $(ENV) $(BACKUP_FILE); \
	fi

# Development helpers
shell:
	@echo "🔧 Connecting to swarm manager..."
	@cd terraform/environments/$(ENV) && \
	MANAGER_IP=$(terraform output -raw swarm_manager_public_ip) && \
	ssh -o StrictHostKeyChecking=no promata@$MANAGER_IP

tunnel:
	@echo "🚇 Creating SSH tunnel for development..."
	@cd terraform/environments/$(ENV) && \
	MANAGER_IP=$(terraform output -raw swarm_manager_public_ip) && \
	ssh -N -L 8080:localhost:8080 -L 5432:localhost:5432 promata@$MANAGER_IP

# Emergency operations
rollback:
	@echo "⏪ Initiating emergency rollback..."
	@$(SCRIPT_DIR)/rollback.sh $(ENV) $(SERVICE)

force-restart:
	@echo "🔄 Force restarting all services..."
	@docker service ls --format "{{.Name}}" | grep promata | xargs -I {} docker service update --force {}

# Cleanup operations
cleanup:
	@echo "🧹 Cleaning up resources..."
	@docker system prune -af --volumes
	@docker volume prune -f

cleanup-logs:
	@echo "🗂️  Cleaning old logs..."
	@find /var/log/promata -name "*.log" -mtime +7 -delete 2>/dev/null || true

# Update specific services
update:
	@$(SCRIPT_DIR)/update-stacks.sh $(ENV) $(SERVICE)

# Quick commands
quick-deploy: terraform-apply stacks-deploy
	@echo "⚡ Quick deployment completed"

quick-health:
	@docker service ls --format "table {{.Name}}\t{{.Replicas}}"
	@echo ""
	@curl -s https://$(shell cd environments/$(ENV) && grep DOMAIN_NAME .env.$(ENV) | cut -d= -f2)/health && echo " - Frontend OK" || echo " - Frontend ERROR"
	@curl -s https://api.$(shell cd environments/$(ENV) && grep DOMAIN_NAME .env.$(ENV) | cut -d= -f2)/health && echo " - Backend OK" || echo " - Backend ERROR"

# Complete destruction
destroy-dev: stacks-destroy terraform-destroy cleanup
	@echo "💥 Dev environment completely destroyed"

# Show infrastructure info
info:
	@echo "ℹ️  Pro-Mata Infrastructure Info:"
	@echo ""
	@echo "📁 Environment: $(ENV)"
	@echo "📊 Terraform State: $(cd terraform/environments/$(ENV) && terraform workspace show)"
	@echo "🌐 Domain: $(cd environments/$(ENV) && grep DOMAIN_NAME .env.$(ENV) | cut -d= -f2 2>/dev/null || echo 'Not configured')"
	@echo "🐳 Docker Context: $(docker context show)"
	@echo ""
	@if docker node ls >/dev/null 2>&1; then \
		echo "📦 Active Services: $(docker service ls --format '{{.Name}}' | wc -l)"; \
		echo "🏷️  Active Containers: $(docker ps --format '{{.Names}}' | wc -l)"; \
	else \
		echo "📦 Docker Swarm: Not initialized"; \
	fi