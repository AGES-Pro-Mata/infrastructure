#!/bin/bash
# ============================================================================
# Import existing AWS resources into Terraform state
# Run this when you get "already exists" errors
# ============================================================================

set -e

cd "$(dirname "$0")/../../iac/aws"

echo "🔄 Importing existing AWS resources into Terraform state..."
echo ""

# Key Pair
echo "📦 Importing Key Pair..."
terraform import module.compute.aws_key_pair.main promata-prod-key 2>/dev/null || echo "   ⚠️  Key Pair already in state or doesn't exist"

# SES Configuration Set
echo "📦 Importing SES Configuration Set..."
terraform import module.email.aws_ses_configuration_set.main promata-prod-ses-config 2>/dev/null || echo "   ⚠️  SES Config already in state or doesn't exist"

# IAM User
echo "📦 Importing IAM User..."
terraform import module.email.aws_iam_user.ses_smtp promata-prod-ses-smtp-user 2>/dev/null || echo "   ⚠️  IAM User already in state or doesn't exist"

# CloudWatch Log Group
echo "📦 Importing CloudWatch Log Group..."
terraform import module.email.aws_cloudwatch_log_group.ses /aws/ses/promata-prod 2>/dev/null || echo "   ⚠️  Log Group already in state or doesn't exist"

echo ""
echo "✅ Import complete!"
echo ""
echo "Next steps:"
echo "  1. Run: terraform plan"
echo "  2. If no errors, run: terraform apply"
