#!/bin/bash
# Deploy script unificado para todos os ambientes

ENV=${1:-dev}
ACTION=${2:-deploy}

# Validar ambiente
case "$ENV" in
    dev|staging|prod)
        echo "🚀 Deploying to: $ENV"
        ;;
    *)
        echo "❌ Environment must be: dev, staging, or prod"
        exit 1
        ;;
esac

# Carregar configurações do ambiente
source "environments/$ENV/.env.$ENV"

# Deploy baseado no ambiente  
case "$ENV" in
    dev|staging)
        echo "🔵 Azure deployment for $ENV"
        terraform -chdir="environments/$ENV/azure" init
        terraform -chdir="environments/$ENV/azure" apply -auto-approve
        ;;
    prod)
        echo "🟢 AWS deployment for production"  
        terraform -chdir="environments/prod/aws" init
        terraform -chdir="environments/prod/aws" apply -auto-approve
        ;;
esac

echo "✅ Deployment to $ENV completed" 