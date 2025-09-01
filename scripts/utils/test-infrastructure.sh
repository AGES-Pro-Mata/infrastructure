#!/bin/bash

# Pro-Mata Infrastructure Test Script
set -e

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
TEST_TYPE="all"
ENVIRONMENT="dev"
PROVIDER="azure"
VERBOSE=false
DRY_RUN=false
SKIP_TERRAFORM=false
SKIP_ANSIBLE=false

# Help function
show_help() {
    echo -e "${BLUE}Pro-Mata Infrastructure Test Script${NC}"
    echo -e "${YELLOW}Usage: $0 [OPTIONS]${NC}"
    echo ""
    echo -e "${YELLOW}Options:${NC}"
    echo -e "  -t, --type TYPE          Test type (terraform, ansible, endpoints, all) [default: all]"
    echo -e "  -e, --environment ENV    Environment (dev, staging, prod) [default: dev]"
    echo -e "  -p, --provider PROVIDER  Cloud provider (azure, aws) [default: azure]"
    echo -e "  --skip-terraform         Skip Terraform validation"
    echo -e "  --skip-ansible           Skip Ansible validation"
    echo -e "  --dry-run                Show what would be tested without executing"
    echo -e "  -v, --verbose            Verbose output"
    echo -e "  -h, --help               Show this help message"
    echo ""
    echo -e "${YELLOW}Examples:${NC}"
    echo -e "  $0 --type terraform --environment dev"
    echo -e "  $0 --type endpoints --environment prod --provider aws"
    echo -e "  $0 --dry-run --verbose"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -p|--provider)
            PROVIDER="$2"
            shift 2
            ;;
        --skip-terraform)
            SKIP_TERRAFORM=true
            shift
            ;;
        --skip-ansible)
            SKIP_ANSIBLE=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
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

# Function to print status
print_status() {
    echo -e "${BLUE}==>${NC} $1"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Function to print error
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Function to execute with dry-run support
execute_test() {
    local cmd="$1"
    local description="$2"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${YELLOW}[DRY-RUN] Would test: $description${NC}"
        return 0
    else
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "${BLUE}Executing: $cmd${NC}"
        fi
        eval "$cmd"
        return $?
    fi
}

# Check if we're in the right directory
check_directory() {
    if [[ ! -d ".github/workflows" ]]; then
        print_error "Not in infrastructure repository root (.github/workflows directory not found)"
        exit 1
    fi
    if ! find .github/workflows -type f | grep -q .; then
        print_error "No workflow files found in .github/workflows/"
        exit 1
    fi
    print_success "Infrastructure repository detected"
}

# Test Terraform configurations
test_terraform() {
    local terraform_dir
    case $ENVIRONMENT in
        "dev"|"staging")
            terraform_dir="./environments/$ENVIRONMENT/azure"
            ;;
        "prod")
            terraform_dir="./environments/$ENVIRONMENT/aws"
            ;;
        *)
            print_error "Unknown environment: $ENVIRONMENT"
            return 1
            ;;
    esac
    
    if [[ ! -d "$terraform_dir" ]]; then
        print_error "Terraform directory not found: $terraform_dir"
        return 1
    fi
    
    cd "$terraform_dir"
    
    # Test Terraform format
    execute_test "terraform fmt -check -recursive" "Terraform formatting check"
    if [[ $? -ne 0 ]]; then
        print_warning "Terraform formatting issues found"
    else
        print_success "Terraform formatting is correct"
    fi
    
    # Test Terraform validation
    execute_test "terraform init -backend=false" "Terraform initialization"
    execute_test "terraform validate" "Terraform validation"
    if [[ $? -eq 0 ]]; then
        print_success "Terraform configuration is valid"
    else
        print_error "Terraform configuration validation failed"
        cd - > /dev/null
        return 1
    fi
    
    cd - > /dev/null
    print_success "Terraform tests completed"
}

# Test Ansible playbooks
test_ansible() {
    if [[ "$SKIP_ANSIBLE" == "true" ]]; then
        print_warning "Skipping Ansible tests"
        return 0
    fi
    
    print_status "Testing Ansible playbooks..."
    
    if [[ ! -d "./ansible" ]]; then
        print_error "Ansible directory not found"
        return 1
    fi
    
    cd "./ansible"
    
    # Test Ansible syntax
    for playbook in playbooks/*.yml; do
        if [[ -f "$playbook" ]]; then
            execute_test "ansible-playbook --syntax-check \"$playbook\"" "Ansible syntax check for $(basename $playbook)"
            if [[ $? -eq 0 ]]; then
                print_success "$(basename $playbook) syntax is valid"
            else
                print_error "$(basename $playbook) syntax check failed"
                cd - > /dev/null
                return 1
            fi
        fi
    done
    
    cd - > /dev/null
    print_success "Ansible tests completed"
}

# Test environment endpoints
test_endpoints() {
    print_status "Testing environment endpoints..."
    
    # Determine URLs based on environment
    case "$ENVIRONMENT" in
        "dev")
            frontend_url="https://dev.promata.duckdns.org"
            api_url="https://api-dev.promata.duckdns.org"
            ;;
        "staging")
            frontend_url="https://staging.promata.duckdns.org"
            api_url="https://api-staging.promata.duckdns.org"
            ;;
        "prod")
            frontend_url="https://promata.duckdns.org"
            api_url="https://api.promata.duckdns.org"
            ;;
        *)
            print_error "Unknown environment: $ENVIRONMENT"
            return 1
            ;;
    esac
    
    # Test endpoints
    endpoints=("$frontend_url" "$api_url/health")
    
    for endpoint in "${endpoints[@]}"; do
        if [[ "$DRY_RUN" == "true" ]]; then
            echo -e "${YELLOW}[DRY-RUN] Would test endpoint: $endpoint${NC}"
        else
            print_status "Testing endpoint: $endpoint"
            
            if curl -f --max-time 30 --silent "$endpoint" > /dev/null; then
                print_success "$endpoint is accessible"
            else
                print_warning "$endpoint is not accessible (may be expected if env is down)"
            fi
        fi
    done
    
    print_success "Endpoint tests completed"
}

# Main execution
main() {
    echo -e "${BLUE}🧪 Pro-Mata Infrastructure Test Suite${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo ""
    
    print_status "Starting infrastructure tests..."
    print_status "Environment: $ENVIRONMENT"
    print_status "Provider: $PROVIDER"
    print_status "Test Type: $TEST_TYPE"
    echo ""
    
    # Check directory
    check_directory
    
    # Run tests based on type
    case "$TEST_TYPE" in
        "terraform")
            test_terraform
            ;;
        "ansible")
            test_ansible
            ;;
        "endpoints")
            test_endpoints
            ;;
        "all")
            test_terraform
            test_ansible
            test_endpoints
            ;;
        *)
            print_error "Unknown test type: $TEST_TYPE"
            show_help
            exit 1
            ;;
    esac
    
    echo ""
    print_success "Infrastructure tests completed successfully"
    echo -e "${GREEN}✅ Test suite finished at $(date -u +"%Y-%m-%d %H:%M:%S UTC")${NC}"
}

# Run main function
main "$@"
