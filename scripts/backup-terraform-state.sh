#!/bin/bash

ENVIRONMENT=${1:-dev}
BACKUP_LOCATION=${2:-s3}

case $BACKUP_LOCATION in
    "s3")
        # Backup para S3 (AWS)
        aws s3 cp environments/$ENVIRONMENT/azure/terraform.tfstate \
            s3://pro-mata-terraform-states/$ENVIRONMENT/terraform-$(date +%Y%m%d-%H%M%S).tfstate
        ;;
    "azure")
        # Backup para Azure Storage
        az storage blob upload \
            --account-name promodaterraformstates \
            --container-name $ENVIRONMENT \
            --name terraform-$(date +%Y%m%d-%H%M%S).tfstate \
            --file environments/$ENVIRONMENT/azure/terraform.tfstate
        ;;
    "github")
        # Backup para branch GitHub privada
        ./scripts/save-terraform-state.sh $ENVIRONMENT github
        ;;
esac