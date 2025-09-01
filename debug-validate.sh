#!/bin/bash
set -euo pipefail

echo "=== DEBUG VALIDATION ==="

# Test the DNS function only
test_dns_resolution() {
    echo "🔍 Testing DNS Resolution"
    
    local domain="dev.promata.com.br"
    echo "Testing domain: $domain"
    
    # Test main domain
    local dns_result=0
    echo "Running nslookup for $domain..."
    nslookup "$domain" >/dev/null 2>&1 || dns_result=$?
    echo "DNS result: $dns_result"
    
    if [[ $dns_result -eq 0 ]]; then
        echo "✅ DNS resolution for $domain"
    else
        echo "⚠️  DNS resolution for $domain (may not be deployed yet)"
    fi
    
    # Test API subdomain
    local api_domain="api.${domain}"
    echo "Testing API domain: $api_domain"
    dns_result=0
    echo "Running nslookup for $api_domain..."
    nslookup "$api_domain" >/dev/null 2>&1 || dns_result=$?
    echo "API DNS result: $dns_result"
    
    if [[ $dns_result -eq 0 ]]; then
        echo "✅ DNS resolution for $api_domain"
    else
        echo "⚠️  DNS resolution for $api_domain (may not be deployed yet)"
    fi
}

echo "Starting DNS test..."
test_dns_resolution
echo "DNS test completed!"
echo "Script finished successfully"
