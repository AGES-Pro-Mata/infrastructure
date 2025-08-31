# Pro-Mata Infrastructure - Updated for New Structure
.PHONY: help deploy-automated terraform-validate

ENV ?= dev
SERVICE ?= all
DRY_RUN ?= false
CI ?= false

# Detect CI environment
ifeq ($(GITHUB_ACTIONS),true)
	CI = true
endif

help:
	@echo "🏗️  Pro-Mata Infrastructure Commands"
	@echo ""
	@echo "🚀 Main Commands:"
	@echo "  deploy-automated ENV=dev    Complete automated deployment"
	@echo "  update-dev ENV=dev          Update services"  
	@echo "  destroy-ENV                 Destroy environment"
	@echo "  health ENV=dev              Health checks"
	@echo "  status ENV=dev              Show status"
	@echo ""
	@echo "🔧 Component Commands:"
	@echo "  terraform-init ENV=dev      Initialize Terraform"
	@echo "  terraform-apply ENV=dev     Apply Terraform changes"
	@echo "  ansible-deploy ENV=dev      Deploy with Ansible"
	@echo "  stacks-deploy ENV=dev       Deploy Docker stacks"

# Validation commands
terraform-validate:
	@echo "🔍 Validating Terraform for $(ENV)..."
	@cd environments/$(ENV)/azure && terraform fmt -check -recursive
	@cd environments/$(ENV)/azure && terraform init -backend=false
	@cd environments/$(ENV)/azure && terraform validate

ansible-validate:
	@echo "🔍 Validating Ansible playbooks..."
	@for playbook in ansible/playbooks/*.yml; do \
		if [ -f "$$playbook" ]; then \
			ansible-playbook --syntax-check "$$playbook" || exit 1; \
		fi \
	done

# Terraform commands (updated paths)
terraform-init:
	@echo "🏗️  Initializing Terraform for $(ENV)..."
ifeq ($(CI),true)
	@cd environments/$(ENV)/azure && terraform init -upgrade
else
	@if [ ! -f "environments/$(ENV)/backend.tf" ]; then \
		echo "Setting up Azure Backend..."; \
		chmod +x environments/$(ENV)/azure/backend-setup.sh && environments/$(ENV)/azure/backend-setup.sh; \
	fi
	@cd environments/$(ENV)/azure && terraform init
endif

terraform-plan: terraform-init
	@echo "📋 Planning Terraform changes for $(ENV)..."
	@cd environments/$(ENV)/azure && terraform plan -out=tfplan
ifeq ($(DRY_RUN),true)
	@echo "Dry run completed - no changes applied"
else
	@echo "Plan saved to tfplan"
endif

terraform-apply: terraform-plan  
	@echo "🚀 Applying Terraform changes for $(ENV)..."
ifneq ($(DRY_RUN),true)
	@cd environments/$(ENV)/azure && terraform apply -auto-approve tfplan
	@cd environments/$(ENV)/azure && terraform output -json > terraform-outputs.json
endif

terraform-apply-automated:
	@echo "🚀 Applying Terraform changes (automated)..."
	@cd environments/$(ENV)/azure && terraform init -upgrade || true
	@cd environments/$(ENV)/azure && terraform apply -auto-approve
	@cd environments/$(ENV)/azure && terraform output -json > terraform-outputs.json

terraform-destroy:
	@echo "💥 Destroying Terraform infrastructure for $(ENV)..."
	@cd environments/$(ENV)/azure && terraform init -upgrade || true
	@cd environments/$(ENV)/azure && terraform destroy -auto-approve

# Ansible commands
generate-inventory:
	@echo "📋 Generating Ansible inventory from Terraform..."
	@scripts/generate-ansible-inventory.sh $(ENV)

ansible-deploy: generate-inventory
	@echo "🔧 Running Ansible deployment for $(ENV)..."
	@cd ansible && ansible-playbook -i inventory/$(ENV)/hosts.yml playbooks/deploy-complete.yml
ifeq ($(CI),true)
	@cd ansible && ansible-playbook -i inventory/$(ENV)/hosts.yml playbooks/deploy-complete.yml --diff
endif

# Docker Swarm commands  
swarm-init:
	@echo "🐳 Initializing Docker Swarm for $(ENV)..."
	@scripts/swarm-init.sh $(ENV)

stacks-deploy:
	@echo "📦 Deploying Docker stacks for $(ENV)..."
	@scripts/deploy-stacks.sh $(ENV)

# Complete deployment pipeline
deploy-automated: terraform-apply-automated generate-inventory ansible-deploy
	@echo "🎉 FULLY AUTOMATED deployment completed!"
	@$(MAKE) show-deployment-info

# Update commands
update-dev:
	@echo "🔄 Updating $(SERVICE) for $(ENV)..."
	@scripts/update-stacks.sh $(ENV) $(SERVICE)

# Health and status
health:
	@echo "🏥 Running health checks for $(ENV)..."
	@scripts/health-check.sh $(ENV)

status:
	@echo "📊 Infrastructure Status for $(ENV):"
	@if docker node ls >/dev/null 2>&1; then \
		echo "🐳 Docker Swarm: Active"; \
		docker service ls --format "table {{.Name}}\t{{.Replicas}}\t{{.Image}}"; \
	else \
		echo "🐳 Docker Swarm: Not available locally"; \
	fi

# Show deployment information  
show-deployment-info:
	@echo ""
	@echo "📊 Deployment Information for $(ENV):"
	@echo "=========================="
	@cd environments/$(ENV)/azure && \
	if [ -f terraform-outputs.json ]; then \
		MANAGER_IP=$$(cat terraform-outputs.json | jq -r '.swarm_manager_public_ip.value // "N/A"') && \
		DOMAIN=$$(grep DOMAIN_NAME ../.env.$(ENV) 2>/dev/null | cut -d= -f2 || echo "promata.com.br") && \
		echo "🌐 Frontend:    https://$$DOMAIN" && \
		echo "🔧 Backend API: https://api.$$DOMAIN" && \
		echo "📊 Traefik:    https://traefik.$$DOMAIN" && \
		echo "🖥️  SSH Access: ssh ubuntu@$$MANAGER_IP" && \
		echo "📍 Manager IP:  $$MANAGER_IP"; \
	else \
		echo "⚠️  Terraform outputs not found. Run terraform apply first."; \
	fi

# DNS update
dns-update:
	@echo "🌐 Updating DNS for $(ENV)..."
	@scripts/dns-updater.sh $(ENV)

# Destruction commands
destroy-dev:
	@echo "⚠️  Destroying DEV environment..."
	@$(MAKE) terraform-destroy ENV=dev

destroy-staging:
	@echo "⚠️  Destroying STAGING environment..."
ifneq ($(CI),true)
	@echo "Are you sure? Type 'yes' to continue:"
	@read -r confirm && [ "$$confirm" = "yes" ]
endif
	@$(MAKE) terraform-destroy ENV=staging

destroy-prod:
	@echo "🚨 DESTROYING PRODUCTION ENVIRONMENT"
ifneq ($(CI),true)
	@echo "⛔ CRITICAL: Type 'DESTROY_PRODUCTION' to continue:"
	@read -r confirm && [ "$$confirm" = "DESTROY_PRODUCTION" ]
endif
	@$(MAKE) terraform-destroy ENV=prod

# Cleanup
cleanup:
	@echo "🧹 Cleaning up resources..."
	@docker system prune -af --volumes || true

# Environment shortcuts
dev: ENV=dev
dev: deploy-automated

staging: ENV=staging
staging: deploy-automated

prod: ENV=prod  
prod: deploy-automated

# Quick commands
quick-deploy: terraform-apply stacks-deploy
	@echo "⚡ Quick deployment completed for $(ENV)"

quick-health:
	@echo "⚡ Quick health check for $(ENV)..."
	@docker service ls --format "table {{.Name}}\t{{.Replicas}}" 2>/dev/null || echo "Docker not available"