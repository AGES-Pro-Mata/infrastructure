#!/bin/bash
# ============================================================================
# Import ALL existing AWS/Cloudflare resources into Terraform state
# Run this BEFORE terraform apply when you get "already exists" errors
# 
# Usage: ./import-all-existing-resources.sh [--auto]
#   --auto: Skip confirmations (for CI/CD)
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "${SCRIPT_DIR}/../../iac/aws"

AUTO_MODE=false
if [[ "$1" == "--auto" ]]; then
    AUTO_MODE=true
fi

REGION="${AWS_REGION:-sa-east-1}"
PROJECT="promata-prod"

echo "🔄 Terraform Import Script"
echo "=========================="
echo "Region: $REGION"
echo "Project: $PROJECT"
echo ""

# Function to safely import a resource
import_resource() {
    local tf_address="$1"
    local aws_id="$2"
    local description="$3"
    
    echo "📦 Importing: $description"
    echo "   TF Address: $tf_address"
    echo "   AWS ID: $aws_id"
    
    if terraform state show "$tf_address" &>/dev/null; then
        echo "   ✅ Already in state, skipping"
        return 0
    fi
    
    if terraform import "$tf_address" "$aws_id" 2>/dev/null; then
        echo "   ✅ Imported successfully"
        return 0
    else
        echo "   ⚠️  Import failed (resource may not exist)"
        return 0  # Don't fail the script
    fi
}

# ============================================================================
# 1. EC2 KEY PAIR
# ============================================================================
echo ""
echo "=== EC2 Key Pair ==="
if aws ec2 describe-key-pairs --key-names "${PROJECT}-key" --region $REGION &>/dev/null; then
    import_resource "module.compute.aws_key_pair.main" "${PROJECT}-key" "EC2 Key Pair"
else
    echo "   ℹ️  Key pair does not exist, will be created"
fi

# ============================================================================
# 2. SES CONFIGURATION SET
# ============================================================================
echo ""
echo "=== SES Configuration Set ==="
if aws ses describe-configuration-set --configuration-set-name "${PROJECT}-ses-config" --region $REGION &>/dev/null; then
    import_resource "module.email.aws_ses_configuration_set.main" "${PROJECT}-ses-config" "SES Configuration Set"
else
    echo "   ℹ️  SES Configuration Set does not exist, will be created"
fi

# ============================================================================
# 3. IAM USER FOR SES SMTP
# ============================================================================
echo ""
echo "=== IAM User ==="
if aws iam get-user --user-name "${PROJECT}-ses-smtp-user" &>/dev/null; then
    import_resource "module.email.aws_iam_user.ses_smtp" "${PROJECT}-ses-smtp-user" "IAM User (SES SMTP)"
else
    echo "   ℹ️  IAM User does not exist, will be created"
fi

# ============================================================================
# 4. CLOUDWATCH LOG GROUP
# ============================================================================
echo ""
echo "=== CloudWatch Log Group ==="
if aws logs describe-log-groups --log-group-name-prefix "/aws/ses/${PROJECT}" --region $REGION --query "logGroups[?logGroupName=='/aws/ses/${PROJECT}'].logGroupName" --output text | grep -q "/aws/ses/${PROJECT}"; then
    import_resource "module.email.aws_cloudwatch_log_group.ses" "/aws/ses/${PROJECT}" "CloudWatch Log Group"
else
    echo "   ℹ️  CloudWatch Log Group does not exist, will be created"
fi

# ============================================================================
# 5. SES DOMAIN IDENTITY
# ============================================================================
echo ""
echo "=== SES Domain Identity ==="
DOMAIN_NAME="${TF_VAR_domain_name:-promata.com.br}"
if aws ses get-identity-verification-attributes --identities "$DOMAIN_NAME" --region $REGION --query "VerificationAttributes.\"${DOMAIN_NAME}\".VerificationStatus" --output text 2>/dev/null | grep -qE "Success|Pending"; then
    import_resource "module.email.aws_ses_domain_identity.main" "$DOMAIN_NAME" "SES Domain Identity"
else
    echo "   ℹ️  SES Domain Identity does not exist, will be created"
fi

# ============================================================================
# 6. ELASTIC IPS - Check and warn about limits
# ============================================================================
echo ""
echo "=== Elastic IPs (Status Check) ==="
TOTAL_EIPS=$(aws ec2 describe-addresses --region $REGION --query "length(Addresses)" --output text)
UNASSOCIATED_EIPS=$(aws ec2 describe-addresses --region $REGION --query "length(Addresses[?AssociationId==null])" --output text)

echo "   Total EIPs: $TOTAL_EIPS"
echo "   Unassociated: $UNASSOCIATED_EIPS"

if [ "$TOTAL_EIPS" -ge 5 ] && [ "$UNASSOCIATED_EIPS" -gt 0 ]; then
    echo ""
    echo "   ⚠️  WARNING: EIP limit may be reached!"
    echo "   Unassociated EIPs that can be released:"
    aws ec2 describe-addresses --region $REGION \
        --query "Addresses[?AssociationId==null].[AllocationId,PublicIp,Tags[?Key=='Name'].Value|[0]]" \
        --output table
    
    if [ "$AUTO_MODE" = true ]; then
        echo ""
        echo "   🗑️  AUTO MODE: Releasing unassociated EIPs..."
        for alloc_id in $(aws ec2 describe-addresses --region $REGION --query "Addresses[?AssociationId==null].AllocationId" --output text); do
            echo "   Releasing: $alloc_id"
            aws ec2 release-address --allocation-id "$alloc_id" --region $REGION || true
        done
    else
        echo ""
        echo "   Run with --auto to release automatically, or manually release:"
        echo "   aws ec2 release-address --allocation-id <ID> --region $REGION"
    fi
fi

# ============================================================================
# 7. CLOUDFLARE DNS RECORDS (if zone ID available)
# ============================================================================
echo ""
echo "=== Cloudflare DNS Records ==="
if [ -n "$CLOUDFLARE_API_TOKEN" ] && [ -n "$CLOUDFLARE_ZONE_ID" ]; then
    echo "   Checking for existing DNS records..."
    
    # Get existing records
    RECORDS=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records" \
        -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
        -H "Content-Type: application/json" | jq -r '.result[] | "\(.type) \(.name) \(.id)"' 2>/dev/null || echo "")
    
    if [ -n "$RECORDS" ]; then
        echo "   Found existing records. Import commands (run manually if needed):"
        echo ""
        
        # MX Record
        MX_ID=$(echo "$RECORDS" | grep "^MX " | head -1 | awk '{print $3}')
        if [ -n "$MX_ID" ]; then
            echo "   # MX Record:"
            echo "   terraform import 'module.dns[0].cloudflare_record.mx[0]' ${CLOUDFLARE_ZONE_ID}/${MX_ID}"
        fi
        
        # SPF/TXT Record
        SPF_ID=$(echo "$RECORDS" | grep "^TXT " | grep -i "spf" | head -1 | awk '{print $3}')
        if [ -n "$SPF_ID" ]; then
            echo "   # SPF Record:"
            echo "   terraform import 'module.dns[0].cloudflare_record.spf[0]' ${CLOUDFLARE_ZONE_ID}/${SPF_ID}"
        fi
        
        # A Records for API
        API_ID=$(echo "$RECORDS" | grep "^A api" | head -1 | awk '{print $3}')
        if [ -n "$API_ID" ]; then
            echo "   # API A Record:"
            echo "   terraform import 'module.dns[0].cloudflare_record.api' ${CLOUDFLARE_ZONE_ID}/${API_ID}"
        fi
    else
        echo "   ℹ️  No existing records found or couldn't fetch"
    fi
else
    echo "   ⚠️  CLOUDFLARE_API_TOKEN or CLOUDFLARE_ZONE_ID not set, skipping DNS import"
    echo "   Set these environment variables to enable Cloudflare record import"
fi

# ============================================================================
# SUMMARY
# ============================================================================
echo ""
echo "============================================"
echo "✅ Import check completed!"
echo ""
echo "Next steps:"
echo "  1. Review any warnings above"
echo "  2. Run: terraform plan"
echo "  3. If no errors: terraform apply"
echo "============================================"
