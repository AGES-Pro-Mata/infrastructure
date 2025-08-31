#!/bin/bash  

ENVIRONMENT=${1:-dev}
BACKUP_FILE=${2}

if [[ -z "$BACKUP_FILE" ]]; then
    echo "Uso: $0 [environment] [backup_file]"
    exit 1
fi

# Criar backup do estado atual
cp environments/$ENVIRONMENT/azure/terraform.tfstate \
   environments/$ENVIRONMENT/azure/terraform.tfstate.backup-$(date +%Y%m%d-%H%M%S)

# Restaurar estado
cp $BACKUP_FILE environments/$ENVIRONMENT/azure/terraform.tfstate

echo "Estado restaurado. Execute 'terraform plan' para verificar diferenças."