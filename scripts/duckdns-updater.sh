#!/bin/bash
# DuckDNS Updater Script - Pro-Mata Infrastructure

set -e

ENV=${1:-dev}
SCRIPT_DIR="$(dirname "$0")"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$PROJECT_ROOT/environments/$ENV/.env.$ENV"

# Load environment
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo "❌ Environment file not found: $ENV_FILE"
    exit 1
fi

# Validate required variables
if [[ -z "$DUCKDNS_TOKEN" ]] || [[ -z "$DUCKDNS_DOMAIN" ]]; then
    echo "❌ DUCKDNS_TOKEN and DUCKDNS_DOMAIN must be set"
    exit 1
fi

# Get current public IP
get_public_ip() {
    local ip
    ip=$(curl -s http://checkip.amazonaws.com/) || \
    ip=$(curl -s https://ipinfo.io/ip) || \
    ip=$(curl -s https://api.ipify.org)
    echo "$ip"
}

# Update DuckDNS
update_dns() {
    local current_ip="$1"
    local url="https://www.duckdns.org/update?domains=$DUCKDNS_DOMAIN&token=$DUCKDNS_TOKEN&ip=$current_ip"
    
    echo "🌐 Updating DNS: $DUCKDNS_DOMAIN.duckdns.org → $current_ip"
    
    local response
    response=$(curl -s "$url")
    
    if [[ "$response" == "OK" ]]; then
        echo "✅ DNS updated successfully"
        return 0
    else
        echo "❌ DNS update failed: $response"
        return 1
    fi
}

# Main execution
main() {
    local current_ip
    current_ip=$(get_public_ip)
    
    if [[ -z "$current_ip" ]]; then
        echo "❌ Could not determine public IP"
        exit 1
    fi
    
    echo "📍 Current IP: $current_ip"
    
    # Check if IP changed (optional caching)
    local cache_file="/tmp/duckdns_last_ip_$DUCKDNS_DOMAIN"
    
    if [[ -f "$cache_file" ]]; then
        local last_ip
        last_ip=$(cat "$cache_file")
        
        if [[ "$current_ip" == "$last_ip" ]]; then
            echo "✅ IP unchanged, skipping update"
            exit 0
        fi
    fi
    
    # Update DNS
    if update_dns "$current_ip"; then
        echo "$current_ip" > "$cache_file"
        
        # Verify DNS propagation (optional)
        sleep 5
        local resolved_ip
        resolved_ip=$(nslookup "$DUCKDNS_DOMAIN.duckdns.org" 8.8.8.8 | grep -A1 'Name:' | tail -1 | awk '{print $2}' 2>/dev/null || true)
        
        if [[ "$resolved_ip" == "$current_ip" ]]; then
            echo "✅ DNS propagation verified"
        else
            echo "⏳ DNS propagation in progress..."
        fi
    else
        exit 1
    fi
}

main "$@"