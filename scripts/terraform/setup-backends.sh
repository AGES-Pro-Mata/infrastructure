#!/bin/bash
# ============================================================================
# Setup All Terraform Backends
# Configura backends para AWS (S3) e Azure (Blob Storage)
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "🚀 Terraform Backend Setup"
echo "=========================="
echo ""

# Menu
echo "Selecione o backend para configurar:"
echo ""
echo "  1) AWS (S3 + DynamoDB)"
echo "  2) Azure (Blob Storage)"
echo "  3) Ambos"
echo "  4) Verificar status dos backends"
echo ""
read -p "Opção [1-4]: " option

case $option in
    1)
        echo ""
        echo "📦 Configurando backend AWS..."
        bash "${SCRIPT_DIR}/setup-backend-aws.sh"
        ;;
    2)
        echo ""
        echo "📦 Configurando backend Azure..."
        bash "${SCRIPT_DIR}/setup-backend-azure.sh"
        ;;
    3)
        echo ""
        echo "📦 Configurando backend AWS..."
        bash "${SCRIPT_DIR}/setup-backend-aws.sh"
        echo ""
        echo "📦 Configurando backend Azure..."
        bash "${SCRIPT_DIR}/setup-backend-azure.sh"
        ;;
    4)
        echo ""
        echo "🔍 Verificando status dos backends..."
        echo ""
        
        # Check AWS
        echo "=== AWS Backend ==="
        if command -v aws &> /dev/null; then
            if aws s3 ls s3://promata-terraform-state 2>/dev/null; then
                echo "✅ S3 bucket existe"
                aws s3 ls s3://promata-terraform-state --recursive 2>/dev/null | head -5
            else
                echo "❌ S3 bucket não encontrado ou sem acesso"
            fi
            
            if aws dynamodb describe-table --table-name promata-terraform-locks --region sa-east-1 2>/dev/null | grep -q "ACTIVE"; then
                echo "✅ DynamoDB table existe e está ativa"
            else
                echo "❌ DynamoDB table não encontrada"
            fi
        else
            echo "⚠️  AWS CLI não instalado"
        fi
        
        echo ""
        echo "=== Azure Backend ==="
        if command -v az &> /dev/null; then
            if az storage account show --name promatatfstate --resource-group rg-promata-terraform 2>/dev/null | grep -q "Succeeded"; then
                echo "✅ Storage Account existe"
                az storage blob list --account-name promatatfstate --container-name tfstate --output table 2>/dev/null | head -5
            else
                echo "❌ Storage Account não encontrada ou sem acesso"
            fi
        else
            echo "⚠️  Azure CLI não instalado"
        fi
        ;;
    *)
        echo "❌ Opção inválida"
        exit 1
        ;;
esac

echo ""
echo "✅ Concluído!"
