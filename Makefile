# Pro-Mata Infrastructure Automation
.PHONY: help init deploy-dev update-dev destroy-dev status logs

ENV ?= dev
STACK_DIR = docker/stacks
SCRIPT_DIR = scripts

help:
	@echo "🏗️  Pro-Mata Infrastructure Commands"
	@echo ""
	@echo "🚀 Main Commands:"
	@echo "  init                    Initialize infrastructure"
	@echo "  deploy-dev              Deploy dev environment"
	@echo "  update-dev              Update services"
	@echo "  destroy-dev             Destroy dev environment"
	@echo "  status                  Show infrastructure status"
	@echo ""
	@echo "🔧 Component Commands:"
	@echo "  terraform-apply         Apply Terraform changes"
	@echo "  swarm-init              Initialize Docker Swarm"
	@echo "  stacks-deploy           Deploy all stacks"
	@echo "  dns-update              Update DuckDNS"
	@echo ""
	@echo "📊 Monitoring:"
	@echo "  logs SERVICE=name       Show service logs"
	@echo "  health                  Health check"
	@echo "  backup                  Backup database"

# Initialize complete infrastructure
init: terraform-init ansible-setup swarm-init

# Complete deployment
deploy-dev: terraform-apply ansible-configure stacks-deploy dns-update
	@echo "✅ Dev environment deployed"

# Update existing deployment
update-dev: stacks-update dns-update
	@echo "✅ Services updated"

# Terraform commands
terraform-init:
	@echo "🏗️  Initializing Terraform..."
	cd terraform/environments/$(ENV) && terraform init

terraform-plan:
	@echo "📋 Planning Terraform changes..."
	cd terraform/environments/$(ENV) && terraform plan -var-file="../../../environments/$(ENV)/terraform.tfvars"

terraform-apply: terraform-plan
	@echo "🚀 Applying Terraform changes..."
	cd terraform/environments/$(ENV) && terraform apply -var-file="../../../environments/$(ENV)/terraform.tfvars" -auto-approve

terraform-destroy:
	@echo "💥 Destroying infrastructure..."
	cd terraform/environments/$(ENV) && terraform destroy -var-file="../../../environments/$(ENV)/terraform.tfvars" -auto-approve

# Ansible commands
ansible-setup:
	@echo "⚙️  Setting up Ansible..."
	cd ansible && ansible-galaxy install -r requirements.yml

ansible-configure:
	@echo "🔧 Configuring with Ansible..."
	cd ansible && ansible-playbook -i inventory/$(ENV) playbooks/site.yml

# Docker Swarm commands
swarm-init:
	@echo "🐳 Initializing Docker Swarm..."
	$(SCRIPT_DIR)/swarm-init.sh $(ENV)

networks-create:
	@echo "🌐 Creating Docker networks..."
	docker network create --driver overlay --attachable promata_public || true
	docker network create --driver overlay --attachable promata_internal || true
	docker network create --driver overlay --attachable promata_database || true

stacks-deploy: networks-create
	@echo "📦 Deploying stacks..."
	$(SCRIPT_DIR)/deploy-stacks.sh $(ENV)

stacks-update:
	@echo "🔄 Updating stacks..."
	$(SCRIPT_DIR)/update-stacks.sh $(ENV)

stacks-destroy:
	@echo "🗑️  Removing stacks..."
	docker stack rm promata-proxy promata-app promata-database || true

# DNS and SSL
dns-update:
	@echo "🌐 Updating DNS..."
	$(SCRIPT_DIR)/duckdns-updater.sh

# Monitoring and logs
status:
	@echo "📊 Infrastructure Status:"
	@echo ""
	@docker node ls 2>/dev/null || echo "❌ Swarm not initialized"
	@echo ""
	@docker service ls 2>/dev/null || echo "❌ No services running"

logs:
	@if [ -z "$(SERVICE)" ]; then \
		echo "❌ Usage: make logs SERVICE=service-name"; \
		docker service ls; \
	else \
		docker service logs -f --tail 100 $(SERVICE); \
	fi

health:
	@echo "🏥 Health Check:"
	@$(SCRIPT_DIR)/health-check.sh

# Database operations
backup:
	@echo "💾 Creating database backup..."
	$(SCRIPT_DIR)/backup-database.sh

restore:
	@echo "♻️  Restoring database..."
	$(SCRIPT_DIR)/restore-database.sh $(BACKUP_FILE)

# Cleanup
cleanup:
	@echo "🧹 Cleaning up resources..."
	docker system prune -af --volumes
	docker volume prune -f

# Development helpers
shell-manager:
	@echo "🔧 SSH to swarm manager..."
	$(SCRIPT_DIR)/ssh-manager.sh

tunnel:
	@echo "🚇 Creating SSH tunnel for services..."
	$(SCRIPT_DIR)/create-tunnel.sh

# Emergency commands
rollback:
	@echo "⏪ Rolling back services..."
	$(SCRIPT_DIR)/rollback.sh

force-restart:
	@echo "🔄 Force restarting all services..."
	docker service ls --format "{{.Name}}" | xargs -I {} docker service update --force {}

destroy-dev: stacks-destroy terraform-destroy
	@echo "💥 Dev environment destroyed"