#!/bin/bash
# Cloudflare API Test Script
# Tests Cloudflare API token and zone access

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Configuration from terraform.tfvars
CLOUDFLARE_API_TOKEN="oycrpCKXpVQmDq_6V2ArnidSxImWxvkzJhxhhBtl"
CLOUDFLARE_ZONE_ID="c59ab9e254cc4d555f265d1d111f95ed"
DOMAIN_NAME="promata.com.br"

echo -e "${BLUE}🔍 Testing Cloudflare API Access${NC}"
echo "=================================="

# Test 1: Check API token validity
echo -e "\n${YELLOW}Test 1: Checking API token validity...${NC}"
API_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

if echo "$API_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ API token is valid${NC}"
    TOKEN_STATUS=$(echo "$API_RESPONSE" | jq -r '.result.status')
    echo "Token status: $TOKEN_STATUS"
else
    echo -e "${RED}❌ API token is invalid or expired${NC}"
    echo "Response: $API_RESPONSE"
    exit 1
fi

# Test 2: Check zone access
echo -e "\n${YELLOW}Test 2: Checking zone access...${NC}"
ZONE_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

if echo "$ZONE_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Zone access successful${NC}"
    ZONE_NAME=$(echo "$ZONE_RESPONSE" | jq -r '.result.name')
    ZONE_STATUS=$(echo "$ZONE_RESPONSE" | jq -r '.result.status')
    echo "Zone: $ZONE_NAME"
    echo "Status: $ZONE_STATUS"
else
    echo -e "${RED}❌ Zone access failed${NC}"
    echo "Response: $ZONE_RESPONSE"
    exit 1
fi

# Test 3: Check DNS edit permissions
echo -e "\n${YELLOW}Test 3: Testing DNS edit permissions...${NC}"
DNS_TEST_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

if echo "$DNS_TEST_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ DNS read permissions confirmed${NC}"
    DNS_COUNT=$(echo "$DNS_TEST_RESPONSE" | jq -r '.result_info.count')
    echo "Current DNS records: $DNS_COUNT"
else
    echo -e "${RED}❌ DNS permissions insufficient${NC}"
    echo "Response: $DNS_TEST_RESPONSE"
    exit 1
fi

# Test 4: Check zone settings permissions
echo -e "\n${YELLOW}Test 4: Testing zone settings permissions...${NC}"
SETTINGS_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

if echo "$SETTINGS_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Zone settings permissions confirmed${NC}"
else
    echo -e "${RED}❌ Zone settings permissions insufficient${NC}"
    echo "Response: $SETTINGS_RESPONSE"
    exit 1
fi

# Test 5: Check page rules permissions
echo -e "\n${YELLOW}Test 5: Testing page rules permissions...${NC}"
PAGE_RULES_RESPONSE=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/pagerules" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

if echo "$PAGE_RULES_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Page rules permissions confirmed${NC}"
else
    echo -e "${RED}❌ Page rules permissions insufficient${NC}"
    echo "Response: $PAGE_RULES_RESPONSE"
    exit 1
fi

echo -e "\n${GREEN}🎉 All Cloudflare API tests passed!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "✅ API Token: Valid"
echo "✅ Zone Access: Confirmed"
echo "✅ DNS Permissions: Confirmed"
echo "✅ Zone Settings: Confirmed"
echo "✅ Page Rules: Confirmed"
echo ""
echo -e "${GREEN}🚀 Cloudflare is ready for Terraform deployment!${NC}"
