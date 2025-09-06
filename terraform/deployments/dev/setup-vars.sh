#!/bin/bash

# Terraform Variable Setup Script for Pro-Mata Infrastructure
echo "🔧 Pro-Mata Terraform Variable Setup"
echo "===================================="

# Check current directory
if [[ ! -f "variables.tf" ]]; then
    echo "❌ Error: Run this script from terraform/deployments/dev directory"
    echo "   Current directory: $(pwd)"
    echo "   Expected files: variables.tf, main.tf"
    exit 1
fi

echo "📋 Setting up terraform.tfvars file..."

# Copy example file
if [[ -f "terraform.tfvars.example" ]]; then
    cp terraform.tfvars.example terraform.tfvars
    echo "✅ Created terraform.tfvars from example"
else
    echo "❌ terraform.tfvars.example not found"
    exit 1
fi

echo ""
echo "⚠️  IMPORTANT: You need to configure Cloudflare credentials!"
echo ""
echo "1. Get your Cloudflare API Token:"
echo "   - Go to https://dash.cloudflare.com/profile/api-tokens"
echo "   - Click 'Create Token'"
echo "   - Use 'Edit zone DNS' template"
echo "   - Include Zone: promata.com.br"
echo ""
echo "2. Get your Cloudflare Zone ID:"
echo "   - Go to https://dash.cloudflare.com"
echo "   - Select promata.com.br domain"
echo "   - Copy Zone ID from the right sidebar"
echo ""
echo "3. Edit terraform.tfvars and replace:"
echo "   cloudflare_api_token = \"YOUR_CLOUDFLARE_API_TOKEN_HERE\""
echo "   cloudflare_zone_id = \"YOUR_CLOUDFLARE_ZONE_ID_HERE\""
echo ""
echo "4. Then run:"
echo "   terraform plan"
echo "   terraform apply"

echo ""
echo "🎯 Current Issues Fixed:"
echo "✅ Project name: myproject → pro-mata"
echo "✅ Resource group: rg-myproject-dev → rg-pro-mata-dev"
echo "✅ Storage account: myprojectdevstore → promatadevstg"
echo "✅ Domain: dev.example.com → promata.com.br"
echo "✅ Docker images: Updated to norohim/pro-mata-*"

echo ""
echo "🔄 This will prevent infrastructure recreation"
echo "   Only DNS records will be added/updated"
