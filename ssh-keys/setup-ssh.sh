#!/bin/bash
# SSH Setup Script for Pro-Mata Infrastructure
# This script sets up SSH access to deployed VMs

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KEY_FILE="$SCRIPT_DIR/dev-ssh-key"
CONFIG_FILE="$SCRIPT_DIR/ssh-config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔑 Setting up SSH access for Pro-Mata dev infrastructure...${NC}"

# Check if key file exists
if [[ ! -f "$KEY_FILE" ]]; then
    echo -e "${RED}❌ SSH key file not found: $KEY_FILE${NC}"
    echo "Please run the deployment script first to extract SSH keys."
    exit 1
fi

# Start SSH agent if not running
if [[ -z "${SSH_AGENT_PID:-}" ]]; then
    echo "Starting SSH agent..."
    eval "$(ssh-agent -s)"
fi

# Add key to SSH agent
echo "Adding SSH key to agent..."
if ssh-add "$KEY_FILE"; then
    echo -e "${GREEN}✅ SSH key added to agent successfully${NC}"
else
    echo -e "${RED}❌ Failed to add SSH key to agent${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ SSH access setup complete!${NC}"
echo ""
echo "You can now connect to your VMs using:"
echo "  ssh -F $CONFIG_FILE manager-dev"
echo "  ssh -F $CONFIG_FILE worker-dev"
echo "  ssh -F $CONFIG_FILE swarm-dev"
echo ""
echo "Or directly with the IPs shown in Terraform outputs:"
echo "  ssh ubuntu@<VM_IP>"
echo ""
echo "To make this permanent, add the following to your ~/.bashrc or ~/.zshrc:"
echo "  eval \"$(ssh-agent -s)\""
echo "  ssh-add $HOME/path/to/your/project/ssh-keys/dev-ssh-key"
