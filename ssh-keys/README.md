# SSH Access for Pro-Mata dev Infrastructure

This directory contains SSH keys and configuration for accessing your deployed VMs.

## Files

- `dev-ssh-key` - Private SSH key (keep secure!)
- `dev-ssh-key.pub` - Public SSH key
- `ssh-config` - SSH configuration file for easy access
- `setup-ssh.sh` - Script to set up SSH access

## Quick Setup

Run the setup script to configure SSH access:

```bash
./setup-ssh.sh
```

Or manually:

```bash
# Start SSH agent
eval "$(ssh-agent -s)"

# Add the key
ssh-add dev-ssh-key
```

## Connecting to VMs

### Using SSH config (recommended):

```bash
# Connect to manager (Docker Swarm manager)
ssh -F ssh-config manager-dev

# Connect to worker
ssh -F ssh-config worker-dev

# Connect to swarm (alias for manager)
ssh -F ssh-config swarm-dev
```

### Direct connection:

```bash
# Manager VM
ssh ubuntu@<manager-ip>

# Worker VM  
ssh ubuntu@<worker-ip>
```

## VM Information

Manager VM: Ubuntu 22.04 LTS
Worker VM:  Ubuntu 22.04 LTS

## Security Notes

- Keep the private key file (`dev-ssh-key`) secure
- Never commit private keys to version control
- The `.gitignore` file excludes SSH keys from being committed

## Troubleshooting

If you get "Permission denied" errors:

1. Ensure SSH agent is running: `eval "$(ssh-agent -s)"`
2. Add key to agent: `ssh-add dev-ssh-key`
3. Check key permissions: `chmod 600 dev-ssh-key`

## Getting VM IPs

If you need the current VM IPs:

```bash
cd ../terraform/deployments/dev
terraform output swarm_manager_public_ip
terraform output swarm_worker_public_ip
```
