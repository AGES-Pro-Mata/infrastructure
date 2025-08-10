#!/bin/bash

# Pro-Mata Infrastructure Rollback Script

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
ENVIRONMENT=""
PROVIDER=""
ROLLBACK_STEPS="1"
DRY_RUN="false"
FORCE="false"
BACKUP_STATE="true"

# Help function
show_help() {
    echo -e "${BLUE}Pro-Mata Infrastructure Rollback Script${NC}"
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  --environment ENV       Environment (dev, staging, prod)"
    echo -e "  --provider PROVIDER     Cloud provider (azure, aws)"
    echo -e "  --steps N               Number of steps to rollback (default: 1)"
    echo -e "  --dry-run               Show what would be done without executing"
    echo -e "  --force                 Force rollback without confirmation"
    echo -e "  --no-backup             Skip state backup before rollback"
    echo -e "  -h, --help              Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 --environment dev --provider azure"
    echo -e "  $0 --environment prod --provider aws --dry-run"
    echo -e "  $0 --environment staging --provider azure --steps 2 --force"
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --provider)
            PROVIDER="$2"
            shift 2
            ;;
        --steps)
            ROLLBACK_STEPS="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --no-backup)
            BACKUP_STATE="false"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$ENVIRONMENT" ]] || [[ -z "$PROVIDER" ]]; then
    echo -e "${RED}❌ Error: Environment and provider are required${NC}"
    show_help
    exit 1
fi

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Error: Invalid environment. Must be dev, staging, or prod${NC}"
    exit 1
fi

# Validate provider
if [[ ! "$PROVIDER" =~ ^(azure|aws)$ ]]; then
    echo -e "${RED}❌ Error: Invalid provider. Must be azure or aws${NC}"
    exit 1
fi

# Validate environment-provider combination
if [[ "$ENVIRONMENT" == "prod" && "$PROVIDER" != "aws" ]]; then
    echo -e "${RED}❌ Error: Production environment must use AWS provider${NC}"
    exit 1
fi

if [[ ("$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "staging") && "$PROVIDER" != "azure" ]]; then
    echo -e "${RED}❌ Error: Dev/Staging environments must use Azure provider${NC}"
    exit 1
fi

# Function to log with timestamp
log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
    
    case "$level" in
        "INFO")
            echo -e "${BLUE}[$timestamp] INFO: $message${NC}"
            ;;
        "WARN")
            echo -e "${YELLOW}[$timestamp] WARN: $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}[$timestamp] ERROR: $message${NC}"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[$timestamp] SUCCESS: $message${NC}"
            ;;
    esac
}

# Function to execute command with dry-run support
execute_command() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN] Would execute: $cmd${NC}"
        echo -e "${YELLOW}[DRY-RUN] Description: $description${NC}"
        return 0
    else
        log "INFO" "Executing: $description"
        eval "$cmd"
        return $?
    fi
}

# Function to backup current state
backup_current_state() {
    log "INFO" "Backing up current infrastructure state..."
    
    local backup_dir="./backups/${ENVIRONMENT}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${backup_dir}/state_backup_${timestamp}.tar.gz"
    
    execute_command "mkdir -p $backup_dir" "Create backup directory"
    
    case "$PROVIDER" in
        "azure")
            # Backup Azure state
            execute_command "terraform state pull > ${backup_dir}/terraform_state_${timestamp}.json" \
                "Export Terraform state"
            execute_command "az group export --name pro-mata-${ENVIRONMENT}-rg --include-comments --include-parameter-default-value > ${backup_dir}/azure_resources_${timestamp}.json" \
                "Export Azure resource group"
            ;;
        "aws")
            # Backup AWS state
            execute_command "terraform state pull > ${backup_dir}/terraform_state_${timestamp}.json" \
                "Export Terraform state"
            execute_command "aws cloudformation describe-stacks --stack-name pro-mata-${ENVIRONMENT} > ${backup_dir}/cloudformation_${timestamp}.json" \
                "Export CloudFormation stack"
            ;;
    esac
    
    # Create archive
    execute_command "tar -czf $backup_file -C $backup_dir ." "Create backup archive"
    
    log "SUCCESS" "State backup completed: $backup_file"
}

# Function to get previous deployment state
get_previous_state() {
    local steps="$1"
    log "INFO" "Getting previous deployment state (${steps} steps back)..."
    
    case "$PROVIDER" in
        "azure")
            # For Azure, get from storage account
            execute_command "az storage blob list --account-name promata${ENVIRONMENT}tfstate --container-name deployments --prefix ${ENVIRONMENT}/infrastructure-state --query '[].name' --output tsv | sort -r | head -$((steps + 1)) | tail -1" \
                "Get previous Azure deployment state"
            ;;
        "aws")
            # For AWS, get from S3
            execute_command "aws s3 ls s3://pro-mata-${ENVIRONMENT}-terraform-state/deployments/ --recursive | grep infrastructure-state | sort -r | head -$((steps + 1)) | tail -1" \
                "Get previous AWS deployment state"
            ;;
    esac
}

# Function to rollback infrastructure
rollback_infrastructure() {
    log "INFO" "Starting infrastructure rollback for $ENVIRONMENT ($PROVIDER)..."
    
    local terraform_dir="./environments/${ENVIRONMENT}/terraform"
    
    if [[ ! -d "$terraform_dir" ]]; then
        log "ERROR" "Terraform directory not found: $terraform_dir"
        exit 1
    fi
    
    cd "$terraform_dir"
    
    # Initialize Terraform
    case "$PROVIDER" in
        "azure")
            execute_command "terraform init -backend-config=\"resource_group_name=pro-mata-${ENVIRONMENT}-rg\" -backend-config=\"storage_account_name=promata${ENVIRONMENT}tfstate\" -backend-config=\"container_name=tfstate\" -backend-config=\"key=${ENVIRONMENT}.terraform.tfstate\"" \
                "Initialize Terraform for Azure"
            ;;
        "aws")
            execute_command "terraform init -backend-config=\"bucket=pro-mata-${ENVIRONMENT}-terraform-state\" -backend-config=\"key=${ENVIRONMENT}/terraform.tfstate\" -backend-config=\"region=us-east-1\" -backend-config=\"dynamodb_table=pro-mata-terraform-locks\"" \
                "Initialize Terraform for AWS"
            ;;
    esac
    
    # Get current workspace/state
    execute_command "terraform workspace select ${ENVIRONMENT} || terraform workspace new ${ENVIRONMENT}" \
        "Select Terraform workspace"
    
    # Plan rollback
    execute_command "terraform plan -var-file=\"../variables.tfvars\" -out=rollback-plan" \
        "Plan infrastructure rollback"
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Confirm rollback if not forced
        if [[ "$FORCE" == "false" ]]; then
            echo -e "${YELLOW}⚠️  About to rollback $ENVIRONMENT infrastructure on $PROVIDER${NC}"
            echo -e "${YELLOW}   This will revert $ROLLBACK_STEPS deployment step(s)${NC}"
            echo -e "${YELLOW}   Current time: $(date -u +"%Y-%m-%d %H:%M:%S UTC")${NC}"
            echo ""
            read -p "Are you sure you want to proceed? (yes/no): " confirm
            
            if [[ "$confirm" != "yes" ]]; then
                log "INFO" "Rollback cancelled by user"
                exit 0
            fi
        fi
        
        # Apply rollback
        execute_command "terraform apply rollback-plan" \
            "Apply infrastructure rollback"
    fi
    
    cd - > /dev/null
}

# Function to rollback application services
rollback_application_services() {
    log "INFO" "Rolling back application services..."
    
    case "$PROVIDER" in
        "azure")
            # Rollback Docker Swarm services
            execute_command "ansible-playbook -i ../environments/${ENVIRONMENT}/inventory.yml ../../ansible/playbooks/rollback-swarm.yml -e environment=${ENVIRONMENT}" \
                "Rollback Docker Swarm services"
            ;;
        "aws")
            # Rollback ECS services
            execute_command "aws ecs update-service --cluster pro-mata-${ENVIRONMENT} --service pro-mata-backend --task-definition pro-mata-backend:LATEST-1" \
                "Rollback backend ECS service"
            execute_command "aws ecs update-service --cluster pro-mata-${ENVIRONMENT} --service pro-mata-frontend --task-definition pro-mata-frontend:LATEST-1" \
                "Rollback frontend ECS service"
            ;;
    esac
}

# Function to verify rollback
verify_rollback() {
    log "INFO" "Verifying rollback success..."
    
    # Wait for services to stabilize
    execute_command "sleep 60" "Wait for services to stabilize"
    
    # Get environment URLs
    case "$ENVIRONMENT" in
        "dev")
            frontend_url="https://dev.promata.ages.pucrs.br"
            api_url="https://api-dev.promata.ages.pucrs.br"
            ;;
        "staging")
            frontend_url="https://staging.promata.ages.pucrs.br"
            api_url="https://api-staging.promata.ages.pucrs.br"
            ;;
        "prod")
            frontend_url="https://promata.ages.pucrs.br"
            api_url="https://api.promata.ages.pucrs.br"
            ;;
    esac
    
    # Health checks
    if [[ "$DRY_RUN" == "false" ]]; then
        log "INFO" "Performing health checks..."
        
        # Check API health
        if curl -f --max-time 30 "${api_url}/health" > /dev/null 2>&1; then
            log "SUCCESS" "API health check passed"
        else
            log "ERROR" "API health check failed"
            return 1
        fi
        
        # Check frontend
        if curl -f --max-time 30 "$frontend_url" > /dev/null 2>&1; then
            log "SUCCESS" "Frontend health check passed"
        else
            log "ERROR" "Frontend health check failed"
            return 1
        fi
    fi
    
    log "SUCCESS" "Rollback verification completed"
}

# Function to send rollback notification
send_rollback_notification() {
    local status="$1"
    
    if [[ -n "$DISCORD_WEBHOOK_URL" ]]; then
        log "INFO" "Sending rollback notification..."
        
        local webhook_cmd="./notify-deployment.sh --webhook \"$DISCORD_WEBHOOK_URL\" --environment \"$ENVIRONMENT\" --status \"$status\" --deployment-id \"ROLLBACK-$(date +%Y%m%d-%H%M%S)\""
        
        execute_command "$webhook_cmd" "Send Discord notification"
    fi
}

# Main rollback function
main() {
    echo -e "${BLUE}🔄 Pro-Mata Infrastructure Rollback${NC}"
    echo -e "${BLUE}====================================${NC}"
    echo ""
    
    log "INFO" "Starting rollback process..."
    log "INFO" "Environment: $ENVIRONMENT"
    log "INFO" "Provider: $PROVIDER"
    log "INFO" "Rollback Steps: $ROLLBACK_STEPS"
    log "INFO" "Dry Run: $DRY_RUN"
    log "INFO" "Force: $FORCE"
    echo ""
    
    # Production safety check
    if [[ "$ENVIRONMENT" == "prod" && "$FORCE" == "false" && "$DRY_RUN" == "false" ]]; then
        echo -e "${RED}🚨 PRODUCTION ROLLBACK DETECTED 🚨${NC}"
        echo -e "${RED}This is a production rollback that will affect live users!${NC}"
        echo ""
        read -p "Type 'ROLLBACK PRODUCTION' to confirm: " prod_confirm
        
        if [[ "$prod_confirm" != "ROLLBACK PRODUCTION" ]]; then
            log "INFO" "Production rollback cancelled"
            exit 0
        fi
    fi
    
    # Backup current state
    if [[ "$BACKUP_STATE" == "true" ]]; then
        backup_current_state
    fi
    
    # Get previous state information
    get_previous_state "$ROLLBACK_STEPS"
    
    # Perform rollback
    rollback_infrastructure
    rollback_application_services
    
    # Verify rollback
    if verify_rollback; then
        log "SUCCESS" "Rollback completed successfully"
        send_rollback_notification "success"
    else
        log "ERROR" "Rollback verification failed"
        send_rollback_notification "failure"
        exit 1
    fi
    
    echo ""
    log "SUCCESS" "Infrastructure rollback process completed"
    echo -e "${GREEN}✅ Rollback finished at $(date -u +"%Y-%m-%d %H:%M:%S UTC")${NC}"
}

# Run main function
main "$@"
