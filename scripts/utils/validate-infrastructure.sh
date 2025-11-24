#!/bin/bash
# Validate Pro-Mata infrastructure configuration and connectivity
# Usage: ./scripts/validate-infrastructure.sh <environment>

set -euo pipefail

ENVIRONMENT=${1:-dev}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_WARNING=0

echo -e "${BLUE}=== Pro-Mata Infrastructure Validation ===${NC}"
echo "Environment: $ENVIRONMENT"
echo "Date: $(date)"
echo ""

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(dev|staging|prod)$ ]]; then
    echo -e "${RED}❌ Invalid environment. Use: dev, staging, or prod${NC}"
    exit 1
fi

# Helper functions
pass_test() {
    echo -e "${GREEN}✅ $1${NC}"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail_test() {
    echo -e "${RED}❌ $1${NC}"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

warn_test() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    TESTS_WARNING=$((TESTS_WARNING + 1))
}

info_test() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Test DNS resolution
test_dns_resolution() {
    echo -e "${BLUE}🔍 Testing DNS Resolution${NC}"
    
    local domain=""
    case $ENVIRONMENT in
        dev)
            domain="dev.promata.com.br"
            ;;
        staging)
            domain="staging.promata.com.br"
            ;;
        prod)
            domain="promata.com.br"
            ;;
    esac
    
    # Test main domain
    local dns_result=0
    nslookup "$domain" >/dev/null 2>&1 || dns_result=$?
    if [[ $dns_result -eq 0 ]]; then
        pass_test "DNS resolution for $domain"
    else
        warn_test "DNS resolution for $domain (may not be deployed yet)"
    fi
    
    # Test API subdomain
    local api_domain="api.${domain}"
    dns_result=0
    nslookup "$api_domain" >/dev/null 2>&1 || dns_result=$?
    if [[ $dns_result -eq 0 ]]; then
        pass_test "DNS resolution for $api_domain"
    else
        warn_test "DNS resolution for $api_domain (may not be deployed yet)"
    fi
}

# Test SSL certificates
test_ssl_certificates() {
    echo -e "${BLUE}🔒 Testing SSL Certificates${NC}"
    
    local domain=""
    case $ENVIRONMENT in
        dev)
            domain="dev.promata.com.br"
            ;;
        staging)
            domain="staging.promata.com.br"
            ;;
        prod)
            domain="promata.com.br"
            ;;
    esac
    
    # Test main domain SSL
    local curl_result=0
    curl -IsS "https://$domain" >/dev/null 2>&1 || curl_result=$?
    if [[ $curl_result -eq 0 ]]; then
        pass_test "SSL certificate for $domain"
        
        # Check certificate expiry
        EXPIRY=$(echo | openssl s_client -servername "$domain" -connect "$domain:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [[ -n "$EXPIRY" ]]; then
            EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s 2>/dev/null || echo "0")
            CURRENT_EPOCH=$(date +%s)
            DAYS_UNTIL_EXPIRY=$(( (EXPIRY_EPOCH - CURRENT_EPOCH) / 86400 ))
            
            if [[ $DAYS_UNTIL_EXPIRY -gt 30 ]]; then
                pass_test "Certificate expires in $DAYS_UNTIL_EXPIRY days"
            elif [[ $DAYS_UNTIL_EXPIRY -gt 7 ]]; then
                warn_test "Certificate expires in $DAYS_UNTIL_EXPIRY days (renew soon)"
            else
                fail_test "Certificate expires in $DAYS_UNTIL_EXPIRY days (URGENT)"
            fi
        fi
    else
        warn_test "SSL certificate for $domain (may not be deployed yet)"
    fi
    
    # Test API subdomain SSL
    local api_domain="api.${domain}"
    curl_result=0
    curl -IsS "https://$api_domain" >/dev/null 2>&1 || curl_result=$?
    if [[ $curl_result -eq 0 ]]; then
        pass_test "SSL certificate for $api_domain"
    else
        warn_test "SSL certificate for $api_domain (may not be configured yet)"
    fi
}

# Test HTTP endpoints
test_http_endpoints() {
    echo -e "${BLUE}🌐 Testing HTTP Endpoints${NC}"
    
    local domain=""
    case $ENVIRONMENT in
        dev)
            domain="dev.promata.com.br"
            ;;
        staging)
            domain="staging.promata.com.br"
            ;;
        prod)
            domain="promata.com.br"
            ;;
    esac
    
    # Test main application
    local http_result=0
    curl -IsS --max-time 10 "https://$domain" | head -1 | grep -q "200\\|301\\|302" || http_result=$?
    if [[ $http_result -eq 0 ]]; then
        pass_test "Main application accessible at https://$domain"
    else
        warn_test "Main application not accessible at https://$domain (may not be deployed)"
    fi
    
    # Test API health endpoint
    local api_domain="api.${domain}"
    http_result=0
    curl -IsS --max-time 10 "https://$api_domain/health" | head -1 | grep -q "200" || http_result=$?
    if [[ $http_result -eq 0 ]]; then
        pass_test "API health endpoint accessible"
    else
        warn_test "API health endpoint not accessible (may not be deployed)"
    fi
    
    # Test Traefik dashboard
    local traefik_domain="traefik.${domain}"
    if curl -IsS --max-time 10 "https://$traefik_domain" >/dev/null 2>&1; then
        pass_test "Traefik dashboard accessible"
    else
        warn_test "Traefik dashboard not accessible (may be restricted)"
    fi
    
    # Test Grafana
    local grafana_domain="grafana.${domain}"
    if curl -IsS --max-time 10 "https://$grafana_domain" | head -1 | grep -q "200\\|301\\|302"; then
        pass_test "Grafana accessible"
    else
        warn_test "Grafana not accessible (may not be deployed)"
    fi
}

# Test infrastructure configuration
test_infrastructure_config() {
    echo -e "${BLUE}⚙️  Testing Infrastructure Configuration${NC}"
    
    # Check Terraform configuration
    local cloud_provider=""
    case $ENVIRONMENT in
        dev|staging)
            cloud_provider="azure"
            ;;
        prod)
            cloud_provider="aws"
            ;;
    esac
    
    local terraform_dir="$ROOT_DIR/terraform/deployments/$ENVIRONMENT"
    
    if [[ -d "$terraform_dir" ]]; then
        pass_test "Terraform configuration directory exists"
        
        cd "$terraform_dir"
        
        # Validate Terraform configuration
        if ! command -v terraform >/dev/null 2>&1; then
            warn_test "Terraform not installed, skipping validation"
        elif terraform validate >/dev/null 2>&1; then
            pass_test "Terraform configuration is valid"
        else
            fail_test "Terraform configuration is invalid"
        fi
        
        # Check if terraform is initialized
        if [[ -d ".terraform" ]]; then
            pass_test "Terraform is initialized"
        else
            warn_test "Terraform not initialized (run terraform init)"
        fi
        
        cd - >/dev/null
    else
        fail_test "Terraform configuration directory not found: $terraform_dir"
    fi
    
    # Check Ansible configuration
    local ansible_inventory="$ROOT_DIR/ansible/inventory/$ENVIRONMENT"
    
    if [[ -d "$ansible_inventory" ]]; then
        pass_test "Ansible inventory directory exists"
        
        # Check vault file
        if [[ -f "$ansible_inventory/group_vars/vault.yml" ]]; then
            pass_test "Ansible vault file exists"
            
            # Verify vault is encrypted
            if head -1 "$ansible_inventory/group_vars/vault.yml" | grep -q "ANSIBLE_VAULT"; then
                pass_test "Ansible vault is properly encrypted"
            else
                if [[ "$ENVIRONMENT" == "prod" ]]; then
                    fail_test "Ansible vault is not encrypted (required for production)"
                else
                    warn_test "Ansible vault is not encrypted (acceptable for dev/staging)"
                fi
            fi
        else
            warn_test "Ansible vault file not found (may need setup)"
        fi
    else
        warn_test "Ansible inventory directory not found: $ansible_inventory"
    fi
}

# Test Docker services (if accessible)
test_docker_services() {
    echo -e "${BLUE}🐳 Testing Docker Services${NC}"
    
    # This would require SSH access to the server
    # For now, we'll test what we can from external
    
    local domain=""
    case $ENVIRONMENT in
        dev)
            domain="dev.promata.com.br"
            ;;
        staging)
            domain="staging.promata.com.br"
            ;;
        prod)
            domain="promata.com.br"
            ;;
    esac
    
    # Test if services respond with expected headers
    local headers=$(curl -IsS --max-time 10 "https://$domain" 2>/dev/null || echo "")
    
    if echo "$headers" | grep -qi "traefik"; then
        pass_test "Traefik proxy is active"
    else
        warn_test "Traefik proxy headers not detected"
    fi
    
    # Test Docker registry images (if we can access them)
    info_test "Checking Docker images (requires DockerHub access)"
    
    local backend_image="norohim/pro-mata-backend-${ENVIRONMENT}:latest"
    local frontend_image="norohim/pro-mata-frontend-${ENVIRONMENT}:latest"
    
    # These would need docker CLI access
    info_test "Backend image: $backend_image"
    info_test "Frontend image: $frontend_image"
}

# Test backup systems
test_backup_systems() {
    echo -e "${BLUE}💾 Testing Backup Systems${NC}"
    
    # Check if backup directory exists
    local backup_dir="$ROOT_DIR/backups"
    
    if [[ -d "$backup_dir" ]]; then
        pass_test "Backup directory exists"
        
        # Check terraform state backups
        local tf_backup_dir="$backup_dir/terraform-state"
        if [[ -d "$tf_backup_dir" ]] && [[ -n "$(ls -A "$tf_backup_dir" 2>/dev/null)" ]]; then
            local backup_count=$(ls -1 "$tf_backup_dir"/*.tfstate 2>/dev/null | wc -l)
            if [[ $backup_count -gt 0 ]]; then
                pass_test "Found $backup_count Terraform state backups"
                
                # Check age of most recent backup
                local latest_backup=$(ls -t "$tf_backup_dir"/*.tfstate 2>/dev/null | head -1)
                if [[ -f "$latest_backup" ]]; then
                    local backup_age_days=$(( ($(date +%s) - $(stat -c %Y "$latest_backup")) / 86400 ))
                    if [[ $backup_age_days -le 1 ]]; then
                        pass_test "Latest backup is $backup_age_days day(s) old"
                    elif [[ $backup_age_days -le 7 ]]; then
                        warn_test "Latest backup is $backup_age_days day(s) old"
                    else
                        fail_test "Latest backup is $backup_age_days day(s) old (too old)"
                    fi
                fi
            else
                warn_test "No Terraform state backups found"
            fi
        else
            warn_test "Terraform backup directory empty or not found"
        fi
    else
        warn_test "Backup directory not found"
    fi
    
    # Test backup scripts
    if [[ -x "$ROOT_DIR/scripts/backup/backup-terraform-state.sh" ]]; then
        pass_test "Backup script is executable"
    else
        fail_test "Backup script not found or not executable"
    fi
    
    if [[ -x "$ROOT_DIR/scripts/backup/restore-terraform-state.sh" ]]; then
        pass_test "Restore script is executable"
    else
        fail_test "Restore script not found or not executable"
    fi
}

# Test Cloudflare configuration (if configured)
test_cloudflare_config() {
    echo -e "${BLUE}☁️  Testing Cloudflare Configuration${NC}"
    
    if [[ "$ENVIRONMENT" == "prod" ]] || [[ "$ENVIRONMENT" == "staging" ]]; then
        local domain="promata.com.br"
        
        # Check if using Cloudflare
        local headers=$(curl -IsS --max-time 10 "https://$domain" 2>/dev/null || echo "")
        
        if echo "$headers" | grep -qi "cloudflare"; then
            pass_test "Cloudflare is active"
            
            # Check for Cloudflare-specific headers
            if echo "$headers" | grep -qi "cf-ray"; then
                pass_test "Cloudflare CDN is working"
            else
                warn_test "Cloudflare CDN headers not found"
            fi
            
            if echo "$headers" | grep -qi "strict-transport-security"; then
                pass_test "HSTS header present"
            else
                warn_test "HSTS header not found"
            fi
        else
            warn_test "Cloudflare not detected (may be DNS-only mode)"
        fi
    else
        info_test "Cloudflare testing skipped for dev environment"
    fi
}

# Run all tests
echo "Starting validation tests..."
echo ""

test_dns_resolution
echo ""

test_ssl_certificates  
echo ""

test_http_endpoints
echo ""

test_infrastructure_config
echo ""

test_docker_services
echo ""

test_backup_systems
echo ""

test_cloudflare_config
echo ""

# Summary
echo -e "${BLUE}=== Validation Summary ===${NC}"
echo ""
echo -e "${GREEN}Tests Passed: $TESTS_PASSED${NC}"
echo -e "${YELLOW}Warnings: $TESTS_WARNING${NC}"
echo -e "${RED}Tests Failed: $TESTS_FAILED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}🎉 All critical tests passed!${NC}"
    if [[ $TESTS_WARNING -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Please review warnings above${NC}"
    fi
    exit 0
else
    echo -e "${RED}❌ $TESTS_FAILED test(s) failed. Please review and fix issues.${NC}"
    exit 1
fi