#!/bin/bash
# Test Cloudflare setup and DNS propagation for Pro-Mata
# Usage: ./scripts/test-cloudflare-setup.sh

set -euo pipefail

DOMAIN="promata.com.br"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Cloudflare Setup Validation for Pro-Mata ===${NC}"
echo "Domain: $DOMAIN"
echo "Date: $(date)"
echo ""

# Helper functions
pass_test() {
    echo -e "${GREEN}✅ $1${NC}"
}

fail_test() {
    echo -e "${RED}❌ $1${NC}"
}

warn_test() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

info_test() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Test DNS resolution
test_dns_resolution() {
    echo -e "${BLUE}🔍 Testing DNS Resolution${NC}"
    
    local subdomains=("" "www" "api" "traefik" "pgadmin" "grafana")
    
    for subdomain in "${subdomains[@]}"; do
        local full_domain="$DOMAIN"
        if [[ -n "$subdomain" ]]; then
            full_domain="$subdomain.$DOMAIN"
        fi
        
        echo -n "Testing $full_domain... "
        
        if nslookup "$full_domain" >/dev/null 2>&1; then
            local ip=$(nslookup "$full_domain" | awk '/^Address: / { print $2 }' | tail -1)
            echo -e "${GREEN}✅ Resolved to $ip${NC}"
        else
            echo -e "${RED}❌ Failed to resolve${NC}"
        fi
    done
    
    echo ""
}

# Test DNS propagation globally
test_dns_propagation() {
    echo -e "${BLUE}🌍 Testing Global DNS Propagation${NC}"
    
    # List of public DNS servers to test
    local dns_servers=(
        "8.8.8.8:Google"
        "1.1.1.1:Cloudflare"
        "208.67.222.222:OpenDNS"
        "9.9.9.9:Quad9"
    )
    
    for server_info in "${dns_servers[@]}"; do
        local server=$(echo "$server_info" | cut -d: -f1)
        local name=$(echo "$server_info" | cut -d: -f2)
        
        echo -n "Testing via $name ($server)... "
        
        local result=$(nslookup "$DOMAIN" "$server" 2>/dev/null | awk '/^Address: / { print $2 }' | tail -1)
        
        if [[ -n "$result" ]]; then
            echo -e "${GREEN}✅ $result${NC}"
        else
            echo -e "${RED}❌ Failed${NC}"
        fi
    done
    
    echo ""
}

# Test SSL certificates
test_ssl_certificates() {
    echo -e "${BLUE}🔒 Testing SSL Certificates${NC}"
    
    local subdomains=("" "www" "api" "traefik" "pgladmin" "grafana")
    
    for subdomain in "${subdomains[@]}"; do
        local full_domain="$DOMAIN"
        if [[ -n "$subdomain" ]]; then
            full_domain="$subdomain.$DOMAIN"
        fi
        
        echo -n "Testing SSL for $full_domain... "
        
        if curl -IsS --max-time 10 "https://$full_domain" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ SSL working${NC}"
            
            # Get certificate details
            local cert_info=$(echo | openssl s_client -servername "$full_domain" -connect "$full_domain:443" 2>/dev/null | openssl x509 -noout -issuer -subject -enddate 2>/dev/null)
            
            if echo "$cert_info" | grep -qi "cloudflare"; then
                info_test "  Using Cloudflare certificate"
            elif echo "$cert_info" | grep -qi "let's encrypt"; then
                info_test "  Using Let's Encrypt certificate"
            fi
            
            # Check expiry
            local expiry=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
            if [[ -n "$expiry" ]]; then
                info_test "  Expires: $expiry"
            fi
        else
            echo -e "${RED}❌ SSL failed${NC}"
        fi
    done
    
    echo ""
}

# Test HTTP redirects and headers
test_http_behavior() {
    echo -e "${BLUE}🌐 Testing HTTP Behavior${NC}"
    
    # Test HTTP to HTTPS redirect
    echo -n "Testing HTTP → HTTPS redirect... "
    local redirect_response=$(curl -sS -o /dev/null -w "%{http_code}:%{redirect_url}" --max-time 10 "http://$DOMAIN" || echo "000:")
    local status_code=$(echo "$redirect_response" | cut -d: -f1)
    local redirect_url=$(echo "$redirect_response" | cut -d: -f2-)
    
    if [[ "$status_code" == "301" ]] || [[ "$status_code" == "302" ]]; then
        if [[ "$redirect_url" =~ ^https:// ]]; then
            echo -e "${GREEN}✅ Redirects to HTTPS${NC}"
        else
            echo -e "${YELLOW}⚠️  Redirects but not to HTTPS${NC}"
        fi
    else
        echo -e "${RED}❌ No redirect (status: $status_code)${NC}"
    fi
    
    # Test WWW redirect
    echo -n "Testing WWW redirect... "
    local www_response=$(curl -sS -o /dev/null -w "%{http_code}:%{redirect_url}" --max-time 10 "https://www.$DOMAIN" || echo "000:")
    local www_status=$(echo "$www_response" | cut -d: -f1)
    local www_redirect=$(echo "$www_response" | cut -d: -f2-)
    
    if [[ "$www_status" == "301" ]] || [[ "$www_status" == "302" ]]; then
        if [[ "$www_redirect" == "https://$DOMAIN/"* ]]; then
            echo -e "${GREEN}✅ WWW redirects to apex domain${NC}"
        else
            echo -e "${YELLOW}⚠️  WWW redirects but not to apex${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  No WWW redirect configured${NC}"
    fi
    
    # Test security headers
    echo -n "Testing security headers... "
    local headers=$(curl -IsS --max-time 10 "https://$DOMAIN" 2>/dev/null || echo "")
    
    local hsts_found=false
    local cf_found=false
    local security_headers=0
    
    if echo "$headers" | grep -qi "strict-transport-security"; then
        hsts_found=true
        ((security_headers++))
    fi
    
    if echo "$headers" | grep -qi "cf-ray"; then
        cf_found=true
    fi
    
    if echo "$headers" | grep -qi "x-content-type-options"; then
        ((security_headers++))
    fi
    
    if echo "$headers" | grep -qi "x-frame-options"; then
        ((security_headers++))
    fi
    
    echo -e "${GREEN}✅ Found $security_headers security headers${NC}"
    
    if [[ "$cf_found" == true ]]; then
        info_test "  Cloudflare is active (CF-Ray header found)"
    else
        warn_test "  Cloudflare headers not detected"
    fi
    
    if [[ "$hsts_found" == true ]]; then
        info_test "  HSTS enabled"
    else
        warn_test "  HSTS not enabled"
    fi
    
    echo ""
}

# Test Cloudflare-specific features
test_cloudflare_features() {
    echo -e "${BLUE}☁️  Testing Cloudflare Features${NC}"
    
    # Test cache headers
    echo -n "Testing CDN/Cache headers... "
    local cache_headers=$(curl -IsS --max-time 10 "https://$DOMAIN" 2>/dev/null || echo "")
    
    if echo "$cache_headers" | grep -qi "cf-cache-status"; then
        local cache_status=$(echo "$cache_headers" | grep -i "cf-cache-status" | cut -d: -f2 | tr -d ' \r\n')
        echo -e "${GREEN}✅ Cache status: $cache_status${NC}"
    else
        echo -e "${YELLOW}⚠️  No cache headers found${NC}"
    fi
    
    # Test compression
    echo -n "Testing compression... "
    local compressed_size=$(curl -sS -H "Accept-Encoding: gzip" --max-time 10 "https://$DOMAIN" | wc -c)
    local uncompressed_size=$(curl -sS --max-time 10 "https://$DOMAIN" | wc -c)
    
    if [[ $compressed_size -lt $uncompressed_size ]]; then
        local compression_ratio=$(( (uncompressed_size - compressed_size) * 100 / uncompressed_size ))
        echo -e "${GREEN}✅ Compression active (~$compression_ratio% reduction)${NC}"
    else
        echo -e "${YELLOW}⚠️  Compression not detected${NC}"
    fi
    
    # Test geographic performance
    echo -n "Testing CF presence... "
    local cf_headers=$(curl -IsS --max-time 10 "https://$DOMAIN" 2>/dev/null | grep -i "cf-")
    
    if [[ -n "$cf_headers" ]]; then
        echo -e "${GREEN}✅ Cloudflare is active${NC}"
        
        # Extract CF-Ray for location info
        local cf_ray=$(echo "$cf_headers" | grep -i "cf-ray" | cut -d: -f2 | tr -d ' \r\n' | cut -d- -f2)
        if [[ -n "$cf_ray" ]]; then
            info_test "  CF-Ray datacenter code: $cf_ray"
        fi
        
        # Check for CF-IPCountry if available
        local cf_country=$(echo "$cf_headers" | grep -i "cf-ipcountry" | cut -d: -f2 | tr -d ' \r\n')
        if [[ -n "$cf_country" ]]; then
            info_test "  Detected country: $cf_country"
        fi
    else
        echo -e "${RED}❌ Cloudflare not active${NC}"
    fi
    
    echo ""
}

# Test API endpoints
test_api_endpoints() {
    echo -e "${BLUE}🔌 Testing API Endpoints${NC}"
    
    local api_domain="api.$DOMAIN"
    
    # Test API root
    echo -n "Testing API root... "
    local api_response=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "https://$api_domain" || echo "000")
    
    case "$api_response" in
        200)
            echo -e "${GREEN}✅ API responding (200 OK)${NC}"
            ;;
        404)
            echo -e "${YELLOW}⚠️  API root returns 404 (may be expected)${NC}"
            ;;
        500|502|503|504)
            echo -e "${RED}❌ API server error ($api_response)${NC}"
            ;;
        000)
            echo -e "${RED}❌ API not accessible${NC}"
            ;;
        *)
            echo -e "${YELLOW}⚠️  API returned $api_response${NC}"
            ;;
    esac
    
    # Test health endpoint
    echo -n "Testing API health endpoint... "
    local health_response=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "https://$api_domain/health" || echo "000")
    
    if [[ "$health_response" == "200" ]]; then
        echo -e "${GREEN}✅ Health endpoint OK${NC}"
    else
        echo -e "${YELLOW}⚠️  Health endpoint returned $health_response${NC}"
    fi
    
    echo ""
}

# Test PageSpeed and performance
test_performance() {
    echo -e "${BLUE}⚡ Testing Performance${NC}"
    
    # Simple performance test
    echo -n "Testing page load time... "
    local start_time=$(date +%s%N)
    curl -sS --max-time 30 "https://$DOMAIN" >/dev/null 2>&1
    local end_time=$(date +%s%N)
    local load_time=$(( (end_time - start_time) / 1000000 ))  # Convert to milliseconds
    
    if [[ $load_time -lt 1000 ]]; then
        echo -e "${GREEN}✅ Fast load time: ${load_time}ms${NC}"
    elif [[ $load_time -lt 3000 ]]; then
        echo -e "${YELLOW}⚠️  Moderate load time: ${load_time}ms${NC}"
    else
        echo -e "${RED}❌ Slow load time: ${load_time}ms${NC}"
    fi
    
    # Test time to first byte
    echo -n "Testing TTFB... "
    local ttfb=$(curl -o /dev/null -sS -w "%{time_starttransfer}\\n" --max-time 10 "https://$DOMAIN" | cut -d. -f1)
    local ttfb_ms=$(echo "$ttfb * 1000" | bc 2>/dev/null || echo "$ttfb")
    
    if (( $(echo "$ttfb < 0.5" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${GREEN}✅ Fast TTFB: ${ttfb}s${NC}"
    elif (( $(echo "$ttfb < 1.0" | bc -l 2>/dev/null || echo 0) )); then
        echo -e "${YELLOW}⚠️  Moderate TTFB: ${ttfb}s${NC}"
    else
        echo -e "${RED}❌ Slow TTFB: ${ttfb}s${NC}"
    fi
    
    echo ""
}

# Main execution
echo "Starting Cloudflare setup validation..."
echo ""

test_dns_resolution
test_dns_propagation
test_ssl_certificates
test_http_behavior
test_cloudflare_features
test_api_endpoints
test_performance

echo -e "${BLUE}=== Cloudflare Setup Validation Complete ===${NC}"
echo ""
echo -e "${GREEN}🎉 Cloudflare validation finished!${NC}"
echo ""
echo "Next steps if issues found:"
echo "1. Check nameserver configuration at registro.br"
echo "2. Verify Cloudflare DNS records in dashboard"
echo "3. Review SSL/TLS settings in Cloudflare"
echo "4. Check Page Rules configuration"
echo ""
echo "Useful links:"
echo "- Cloudflare Dashboard: https://dash.cloudflare.com"
echo "- SSL Test: https://www.ssllabs.com/ssltest/analyze.html?d=$DOMAIN"
echo "- DNS Checker: https://dnschecker.org/"