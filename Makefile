# ============================================================================
# Makefile
# ============================================================================
.PHONY: help init plan apply destroy validate clean

ENV ?= dev
AWS_REGION ?= us-east-2

help: ## Show this help message
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

init: ## Initialize Terraform for specified environment
	@echo "🚀 Initializing Terraform for $(ENV) environment..."
	cd environments/$(ENV) && terraform init

plan: ## Run Terraform plan for specified environment
	@echo "📋 Planning Terraform changes for $(ENV) environment..."
	cd environments/$(ENV) && terraform plan -var-file=terraform.tfvars

apply: ## Apply Terraform changes for specified environment
	@echo "🚀 Applying Terraform changes for $(ENV) environment..."
	cd environments/$(ENV) && terraform apply -var-file=terraform.tfvars

destroy: ## Destroy infrastructure for specified environment (BE CAREFUL!)
	@echo "⚠️  WARNING: This will destroy all infrastructure for $(ENV) environment!"
	@echo "⚠️  Type 'yes' to continue: "
	@read confirm && [ "$$confirm" = "yes" ] || exit 1
	cd environments/$(ENV) && terraform destroy -var-file=terraform.tfvars

validate: ## Validate Terraform configuration
	@echo "🔍 Validating Terraform configuration..."
	terraform validate
	@for env in dev prod; do \
		echo "Validating $$env environment..."; \
		cd environments/$$env && terraform validate && cd ../..; \
	done

clean: ## Clean Terraform temporary files
	@echo "🧹 Cleaning Terraform temporary files..."
	find . -name ".terraform" -type d -exec rm -rf {} + 2>/dev/null || true
	find . -name "terraform.tfstate.backup" -delete
	find . -name ".terraform.lock.hcl" -delete

fmt: ## Format Terraform files
	@echo "🎨 Formatting Terraform files..."
	terraform fmt -recursive

check: ## Run basic checks (validate + format check)
	@echo "✅ Running basic checks..."
	terraform fmt -check -recursive
	$(MAKE) validate

setup-backend: ## Setup S3 backend and DynamoDB table (run once)
	@echo "🏗️  Setting up Terraform backend infrastructure..."
	cd setup && terraform init && terraform apply

outputs: ## Show outputs for specified environment
	@echo "📊 Showing outputs for $(ENV) environment..."
	cd environments/$(ENV) && terraform output

ssh-manager: ## SSH into manager node
	@echo "🔐 Connecting to manager node..."
	$(eval MANAGER_IP := $(shell cd environments/$(ENV) && terraform output -raw manager_public_ip))
	ssh ubuntu@$(MANAGER_IP)

ssh-worker: ## SSH into worker node
	@echo "🔐 Connecting to worker node..."
	$(eval WORKER_IP := $(shell cd environments/$(ENV) && terraform output -raw worker_public_ip))
	ssh ubuntu@$(WORKER_IP)

status: ## Check infrastructure status
	@echo "📊 Checking infrastructure status for $(ENV) environment..."
	cd environments/$(ENV) && terraform show

logs: ## Show recent CloudWatch logs
	@echo "📋 Showing recent logs for $(ENV) environment..."
	aws logs describe-log-groups --log-group-name-prefix "/aws/ec2/promata-$(ENV)" --region $(AWS_REGION)

# Development shortcuts
dev-init: ## Initialize development environment
	$(MAKE) init ENV=dev

dev-plan: ## Plan development environment
	$(MAKE) plan ENV=dev

dev-apply: ## Apply development environment
	$(MAKE) apply ENV=dev

dev-destroy: ## Destroy development environment
	$(MAKE) destroy ENV=dev

# Production shortcuts
prod-init: ## Initialize production environment
	$(MAKE) init ENV=prod

prod-plan: ## Plan production environment
	$(MAKE) plan ENV=prod

prod-apply: ## Apply production environment
	$(MAKE) apply ENV=prod