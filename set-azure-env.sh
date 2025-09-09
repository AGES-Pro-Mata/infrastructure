#!/bin/bash

# Set Azure environment variables for local development
# You need to replace these with your actual Azure service principal credentials

export ARM_CLIENT_ID="your-azure-client-id-here"
export ARM_CLIENT_SECRET="your-azure-client-secret-here"  
export ARM_SUBSCRIPTION_ID="afe9690f-5e8c-480b-acb3-84f2e9dd4e60"
export ARM_TENANT_ID="your-azure-tenant-id-here"

echo "Azure environment variables set for Terraform"
echo "Now you can run: make deploy-automated ENV=dev"
