#!/bin/bash
# 🔒 Pre-commit Security Check for Pro-Mata Infrastructure
# Prevents committing sensitive data to public repository

set -e

echo "🔍 Running security checks before commit..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

SECURITY_VIOLATIONS=0

# Check for common secrets patterns in staged files only
echo "🔍 Checking staged files for exposed secrets..."

PATTERNS=(
    "password.*=.*[^PLACEHOLDER|CHANGE_ME|REPLACE_WITH]"
    "api.*key.*=.*[^PLACEHOLDER|CHANGE_ME|REPLACE_WITH]"  
    "secret.*=.*[^PLACEHOLDER|CHANGE_ME|REPLACE_WITH]"
    "token.*=.*[^PLACEHOLDER|CHANGE_ME|REPLACE_WITH]"
    "private.*key"
    "-----BEGIN.*PRIVATE KEY-----"
    "aws_access_key_id"
    "aws_secret_access_key"
)

# Get staged files
STAGED_FILES=$(git diff --cached --name-only)

if [ -z "$STAGED_FILES" ]; then
    echo "🔍 No staged files to check."
else
    for pattern in "${PATTERNS[@]}"; do
        if echo "$STAGED_FILES" | xargs grep -l -i -E "$pattern" 2>/dev/null; then
            echo -e "${RED}❌ SECURITY VIOLATION: Found potential secret matching pattern: $pattern${NC}"
            echo -e "${YELLOW}   Files with issues:${NC}"
            echo "$STAGED_FILES" | xargs grep -l -i -E "$pattern" 2>/dev/null | sed 's/^/     /'
            SECURITY_VIOLATIONS=$((SECURITY_VIOLATIONS + 1))
        fi
    done
fi

# Check for specific dangerous files in staged changes
echo "🔍 Checking for dangerous file patterns in staged changes..."

DANGEROUS_FILES=(
    "*.pem"
    "*.key"
    "*id_rsa*"
    "*.p12"
    "*.pfx"
    "*service-account*.json"
    "*.env.production"
    "*.env.real"
    "*secrets*.yml"
    "*vault*.yml"
)

for file_pattern in "${DANGEROUS_FILES[@]}"; do
    if echo "$STAGED_FILES" | grep -E "$file_pattern" 2>/dev/null; then
        echo -e "${RED}❌ SECURITY VIOLATION: Attempting to commit dangerous file: $file_pattern${NC}"
        echo "$STAGED_FILES" | grep -E "$file_pattern" 2>/dev/null | sed 's/^/     /'
        SECURITY_VIOLATIONS=$((SECURITY_VIOLATIONS + 1))
    fi
done

# Check staged content for hardcoded sensitive data (more specific patterns)
echo "🔍 Checking staged content for hardcoded sensitive data..."

SENSITIVE_PATTERNS=(
    "sk-[a-zA-Z0-9]{48}"                                              # OpenAI API keys
    "ghp_[a-zA-Z0-9]{36}"                                             # GitHub tokens
    "xoxb-[0-9]+-[0-9]+-[a-zA-Z0-9]+"                                # Slack tokens
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    if git diff --cached | grep -E "$pattern" 2>/dev/null; then
        echo -e "${RED}❌ SECURITY VIOLATION: Found hardcoded sensitive data matching: $pattern${NC}"
        SECURITY_VIOLATIONS=$((SECURITY_VIOLATIONS + 1))
    fi
done

# Check if .env files in staging have real values (not placeholders)
echo "🔍 Checking staged .env files for real values..."

for env_file in $(echo "$STAGED_FILES" | grep "\.env$"); do
    if [ -f "$env_file" ]; then
        # Check if file contains values that are NOT placeholders
        if grep -E "=.+" "$env_file" | grep -v -E "(PLACEHOLDER|CHANGE_ME|REPLACE_WITH|your_.*_here)" | grep -v -E "^(ENVIRONMENT|ENV_COLOR|ENV_PREFIX|DOMAIN_NAME|SUBDOMAIN_PREFIX|API_SUBDOMAIN|ADMIN_SUBDOMAIN|AZURE_RESOURCE_GROUP|AZURE_LOCATION|VM_SIZE|BACKEND_IMAGE|FRONTEND_IMAGE|REPLICAS|POSTGRES_DB|DATABASE_SIZE|MONITORING_ENABLED|PROMETHEUS_RETENTION)=" | grep -v "^#"; then
            echo -e "${YELLOW}⚠️  WARNING: .env file may contain real values: $env_file${NC}"
            echo -e "${YELLOW}   Lines that may need attention:${NC}"
            grep -E "=.+" "$env_file" | grep -v -E "(PLACEHOLDER|CHANGE_ME|REPLACE_WITH|your_.*_here)" | grep -v -E "^(ENVIRONMENT|ENV_COLOR|ENV_PREFIX|DOMAIN_NAME|SUBDOMAIN_PREFIX|API_SUBDOMAIN|ADMIN_SUBDOMAIN|AZURE_RESOURCE_GROUP|AZURE_LOCATION|VM_SIZE|BACKEND_IMAGE|FRONTEND_IMAGE|REPLICAS|POSTGRES_DB|DATABASE_SIZE|MONITORING_ENABLED|PROMETHEUS_RETENTION)=" | grep -v "^#" | sed 's/^/     /'
        fi
    fi
done

# Final verdict
if [ $SECURITY_VIOLATIONS -gt 0 ]; then
    echo -e "\n${RED}🚨 COMMIT BLOCKED! Found $SECURITY_VIOLATIONS security violations.${NC}"
    echo -e "${YELLOW}Please fix the issues above and try again.${NC}"
    echo -e "\n${YELLOW}💡 Tips:${NC}"
    echo -e "   • Use placeholder values like 'PLACEHOLDER_REPLACE_WITH_YOUR_VALUE'"
    echo -e "   • Move real secrets to .gitignored files"
    echo -e "   • Use environment variables or secure vaults"
    echo -e "   • Check docs/SECURITY.md for best practices"
    exit 1
else
    echo -e "\n${GREEN}✅ Security check passed! Safe to commit.${NC}"
    exit 0
fi
