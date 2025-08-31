# 📋 Pro-Mata Infrastructure Runbook

Streamlined deployment guide for Pro-Mata infrastructure.

## Prerequisites
- Azure CLI, Terraform >= 1.8.0, Docker
- Azure subscription, Custom domain, Docker Hub access
- SSH key pair for VM access

## 🚀 Quick Deployment

### Local Setup
```bash
cp environments/dev/.env.dev.example environments/dev/.env.dev
# Edit: Azure subscription, domain configuration, passwords, SSH key

make deploy-dev  # Full deployment
```

### GitHub Actions
1. Configure repository secrets (Azure auth, app secrets, SSH keys)
2. Push to `feature/dev-environment` or manually trigger workflow
3. Monitor in Actions tab

## 🎯 Access Points

- **Frontend**: https://promata.com.br
- **API**: https://api.promata.com.br  
- **Traefik**: https://traefik.promata.com.br
- **PgAdmin**: https://pgladmin.promata.com.br

## 📊 Management Commands

```bash
# Status and health
make status          # Infrastructure overview
make health          # Health checks
make logs SERVICE=x  # Service logs

# Updates and maintenance  
make update SERVICE=x  # Update service
make rollback         # Emergency rollback
scripts/backup-database.sh  # Database backup
```

## 🔧 Troubleshooting

### Common Issues
```bash
# Service status
docker node ls && docker service ls

# DNS resolution  
nslookup promata.com.br

# Database connectivity
docker exec -it pgbouncer psql -h localhost -p 6432 -U promata -d promata_dev

# SSL/Certificate issues
docker service logs promata-proxy_traefik
```

### Recovery
```bash
# Restart services
docker service update --force SERVICE_NAME

# Redeploy stack
docker stack rm STACK_NAME
docker stack deploy -c COMPOSE_FILE STACK_NAME

# Complete cleanup
make destroy-dev
make deploy-dev
```

## 🔒 Security Notes

- Rotate secrets regularly via `make security-rotate`
- Monitor via `make security-audit` 
- Backup database before major changes
- Test deployments in dev before production

---


**Environment**: Development (Azure East US 2)