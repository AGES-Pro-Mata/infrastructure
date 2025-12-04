#!/bin/bash
# ============================================================================
# Cleanup orphaned AWS resources and import existing ones
# Execute este script para resolver erros de "already exists"
# ============================================================================

set -e

REGION="sa-east-1"
PROJECT="promata-prod"

echo "🔍 Verificando recursos órfãos na AWS..."
echo ""

# ============================================================================
# 1. ELASTIC IPs - Liberar não associados
# ============================================================================
echo "=== Elastic IPs ==="
echo "📋 Listando EIPs não associados..."

UNASSOCIATED_EIPS=$(aws ec2 describe-addresses \
    --region $REGION \
    --query "Addresses[?AssociationId==null].AllocationId" \
    --output text)

if [ -n "$UNASSOCIATED_EIPS" ]; then
    echo "⚠️  EIPs não associados encontrados:"
    aws ec2 describe-addresses \
        --region $REGION \
        --query "Addresses[?AssociationId==null].[AllocationId,PublicIp,Tags[?Key=='Name'].Value|[0]]" \
        --output table
    
    echo ""
    read -p "Deseja liberar esses EIPs? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        for eip in $UNASSOCIATED_EIPS; do
            echo "🗑️  Liberando EIP: $eip"
            aws ec2 release-address --allocation-id $eip --region $REGION
        done
        echo "✅ EIPs liberados"
    fi
else
    echo "✅ Nenhum EIP órfão encontrado"
fi

echo ""

# ============================================================================
# 2. KEY PAIRS - Verificar/Deletar
# ============================================================================
echo "=== Key Pairs ==="
if aws ec2 describe-key-pairs --key-names "${PROJECT}-key" --region $REGION 2>/dev/null; then
    echo "⚠️  Key pair '${PROJECT}-key' existe"
    read -p "Deseja deletar para o Terraform recriar? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        aws ec2 delete-key-pair --key-name "${PROJECT}-key" --region $REGION
        echo "✅ Key pair deletado"
    fi
else
    echo "✅ Key pair não existe"
fi

echo ""

# ============================================================================
# 3. SES Resources
# ============================================================================
echo "=== SES Configuration Set ==="
if aws ses describe-configuration-set --configuration-set-name "${PROJECT}-ses-config" --region $REGION 2>/dev/null; then
    echo "⚠️  SES Configuration Set existe"
    read -p "Deseja deletar? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        aws ses delete-configuration-set --configuration-set-name "${PROJECT}-ses-config" --region $REGION
        echo "✅ SES Configuration Set deletado"
    fi
else
    echo "✅ SES Configuration Set não existe"
fi

echo ""

# ============================================================================
# 4. IAM User
# ============================================================================
echo "=== IAM User ==="
if aws iam get-user --user-name "${PROJECT}-ses-smtp-user" 2>/dev/null; then
    echo "⚠️  IAM User '${PROJECT}-ses-smtp-user' existe"
    read -p "Deseja deletar (incluindo access keys)? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        # Deletar access keys primeiro
        for key in $(aws iam list-access-keys --user-name "${PROJECT}-ses-smtp-user" --query "AccessKeyMetadata[].AccessKeyId" --output text); do
            aws iam delete-access-key --user-name "${PROJECT}-ses-smtp-user" --access-key-id $key
        done
        # Deletar policies
        for policy in $(aws iam list-user-policies --user-name "${PROJECT}-ses-smtp-user" --query "PolicyNames[]" --output text); do
            aws iam delete-user-policy --user-name "${PROJECT}-ses-smtp-user" --policy-name $policy
        done
        # Deletar user
        aws iam delete-user --user-name "${PROJECT}-ses-smtp-user"
        echo "✅ IAM User deletado"
    fi
else
    echo "✅ IAM User não existe"
fi

echo ""

# ============================================================================
# 5. CloudWatch Log Group
# ============================================================================
echo "=== CloudWatch Log Group ==="
if aws logs describe-log-groups --log-group-name-prefix "/aws/ses/${PROJECT}" --region $REGION --query "logGroups[0].logGroupName" --output text 2>/dev/null | grep -q "/aws/ses"; then
    echo "⚠️  CloudWatch Log Group existe"
    read -p "Deseja deletar? (y/N): " confirm
    if [[ $confirm == [yY] ]]; then
        aws logs delete-log-group --log-group-name "/aws/ses/${PROJECT}" --region $REGION
        echo "✅ CloudWatch Log Group deletado"
    fi
else
    echo "✅ CloudWatch Log Group não existe"
fi

echo ""
echo "============================================"
echo "✅ Verificação concluída!"
echo ""
echo "Próximo passo: Re-run terraform apply"
echo "============================================"
