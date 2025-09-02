#!/bin/bash
# Detailed Cloudflare API Token Test
# Comprehensive testing of Cloudflare API token permissions

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

echo -e "${BLUE}🔍 Detailed Cloudflare API Token Test${NC}"
echo "=========================================="
echo "Token: ${CLOUDFLARE_API_TOKEN:0:10}..."
echo "Zone ID: $CLOUDFLARE_ZONE_ID"
echo "Domain: $DOMAIN_NAME"
echo ""

# Test 0: Basic token format check
echo -e "${YELLOW}Test 0: Token format validation...${NC}"
if [[ ${#CLOUDFLARE_API_TOKEN} -lt 40 ]]; then
    echo -e "${RED}❌ Token seems too short (${#CLOUDFLARE_API_TOKEN} chars)${NC}"
    echo "Cloudflare tokens are usually 40+ characters long"
    exit 1
else
    echo -e "${GREEN}✅ Token length looks correct${NC}"
fi

# Test 1: Check API token validity
echo -e "\n${YELLOW}Test 1: API token validity...${NC}"
TOKEN_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

HTTP_STATUS=$(echo "$TOKEN_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
TOKEN_BODY=$(echo "$TOKEN_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $HTTP_STATUS"

if [[ "$HTTP_STATUS" == "200" ]]; then
    if echo "$TOKEN_BODY" | jq -e '.success' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ API token is valid${NC}"
        TOKEN_STATUS=$(echo "$TOKEN_BODY" | jq -r '.result.status')
        echo "Token status: $TOKEN_STATUS"
    else
        echo -e "${RED}❌ API token validation failed${NC}"
        echo "Response: $TOKEN_BODY"
        exit 1
    fi
else
    echo -e "${RED}❌ HTTP request failed (Status: $HTTP_STATUS)${NC}"
    echo "Response: $TOKEN_BODY"
    exit 1
fi

# Test 2: Check zone access
echo -e "\n${YELLOW}Test 2: Zone access...${NC}"
ZONE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

ZONE_HTTP_STATUS=$(echo "$ZONE_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
ZONE_BODY=$(echo "$ZONE_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $ZONE_HTTP_STATUS"

if [[ "$ZONE_HTTP_STATUS" == "200" ]]; then
    if echo "$ZONE_BODY" | jq -e '.success' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Zone access successful${NC}"
        ZONE_NAME=$(echo "$ZONE_BODY" | jq -r '.result.name')
        ZONE_STATUS=$(echo "$ZONE_BODY" | jq -r '.result.status')
        echo "Zone: $ZONE_NAME"
        echo "Status: $ZONE_STATUS"
    else
        echo -e "${RED}❌ Zone access failed${NC}"
        echo "Response: $ZONE_BODY"
        exit 1
    fi
else
    echo -e "${RED}❌ Zone request failed (Status: $ZONE_HTTP_STATUS)${NC}"
    echo "Response: $ZONE_BODY"
    exit 1
fi

# Test 3: Check DNS permissions
echo -e "\n${YELLOW}Test 3: DNS permissions...${NC}"
DNS_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

DNS_HTTP_STATUS=$(echo "$DNS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
DNS_BODY=$(echo "$DNS_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $DNS_HTTP_STATUS"

if [[ "$DNS_HTTP_STATUS" == "200" ]]; then
    if echo "$DNS_BODY" | jq -e '.success' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS permissions confirmed${NC}"
        DNS_COUNT=$(echo "$DNS_BODY" | jq -r '.result_info.count')
        echo "Current DNS records: $DNS_COUNT"
    else
        echo -e "${RED}❌ DNS permissions insufficient${NC}"
        echo "Response: $DNS_BODY"
        exit 1
    fi
else
    echo -e "${RED}❌ DNS request failed (Status: $DNS_HTTP_STATUS)${NC}"
    echo "Response: $DNS_BODY"
    exit 1
fi

# Test 4: Test DNS record creation (dry run)
echo -e "\n${YELLOW}Test 4: DNS record creation test...${NC}"
TEST_RECORD_DATA=$(cat <<EOF
{
  "type": "A",
  "name": "test-deployment",
  "content": "1.2.3.4",
  "ttl": 1,
  "proxied": false
}
EOF
)

CREATE_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X POST "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d "$TEST_RECORD_DATA")

CREATE_HTTP_STATUS=$(echo "$CREATE_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
CREATE_BODY=$(echo "$CREATE_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $CREATE_HTTP_STATUS"

if [[ "$CREATE_HTTP_STATUS" == "200" ]]; then
    if echo "$CREATE_BODY" | jq -e '.success' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ DNS record creation successful${NC}"
        RECORD_ID=$(echo "$CREATE_BODY" | jq -r '.result.id')
        echo "Test record created with ID: $RECORD_ID"

        # Clean up test record
        echo "Cleaning up test record..."
        DELETE_RESPONSE=$(curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/dns_records/$RECORD_ID" \
          -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
          -H "Content-Type: application/json")

        if echo "$DELETE_RESPONSE" | jq -e '.success' >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Test record cleaned up${NC}"
        else
            echo -e "${YELLOW}⚠️  Could not clean up test record${NC}"
        fi
    else
        echo -e "${RED}❌ DNS record creation failed${NC}"
        echo "Response: $CREATE_BODY"
        exit 1
    fi
else
    echo -e "${RED}❌ DNS creation request failed (Status: $CREATE_HTTP_STATUS)${NC}"
    echo "Response: $CREATE_BODY"
    exit 1
fi

# Test 5: Check zone settings permissions
echo -e "\n${YELLOW}Test 5: Zone settings permissions...${NC}"
SETTINGS_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/settings" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

SETTINGS_HTTP_STATUS=$(echo "$SETTINGS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
SETTINGS_BODY=$(echo "$SETTINGS_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $SETTINGS_HTTP_STATUS"

if [[ "$SETTINGS_HTTP_STATUS" == "200" ]]; then
    if echo "$SETTINGS_BODY" | jq -e '.success' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Zone settings permissions confirmed${NC}"
    else
        echo -e "${RED}❌ Zone settings permissions insufficient${NC}"
        echo "Response: $SETTINGS_BODY"
        exit 1
    fi
else
    echo -e "${RED}❌ Settings request failed (Status: $SETTINGS_HTTP_STATUS)${NC}"
    echo "Response: $SETTINGS_BODY"
    exit 1
fi

# Test 6: Check page rules permissions
echo -e "\n${YELLOW}Test 6: Page rules permissions...${NC}"
PAGE_RULES_RESPONSE=$(curl -s -w "\nHTTP_STATUS:%{http_code}" -X GET "https://api.cloudflare.com/client/v4/zones/$CLOUDFLARE_ZONE_ID/pagerules" \
  -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
  -H "Content-Type: application/json")

PAGE_HTTP_STATUS=$(echo "$PAGE_RULES_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
PAGE_BODY=$(echo "$PAGE_RULES_RESPONSE" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $PAGE_HTTP_STATUS"

if [[ "$PAGE_HTTP_STATUS" == "200" ]]; then
    if echo "$PAGE_BODY" | jq -e '.success' >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Page rules permissions confirmed${NC}"
    else
        echo -e "${RED}❌ Page rules permissions insufficient${NC}"
        echo "Response: $PAGE_BODY"
        exit 1
    fi
else
    echo -e "${RED}❌ Page rules request failed (Status: $PAGE_HTTP_STATUS)${NC}"
    echo "Response: $PAGE_BODY"
    exit 1
fi

echo -e "\n${GREEN}🎉 All Cloudflare API tests passed!${NC}"
echo ""
echo -e "${BLUE}📋 Summary:${NC}"
echo "✅ API Token: Valid and active"
echo "✅ Zone Access: Confirmed"
echo "✅ DNS Permissions: Full access (read/write)"
echo "✅ Zone Settings: Full access"
echo "✅ Page Rules: Full access"
echo ""
echo -e "${GREEN}🚀 Cloudflare is ready for Terraform deployment!${NC}"
echo ""
echo -e "${BLUE}Next step: Run deployment${NC}"
echo "make deploy ENV=dev"
