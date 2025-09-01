# 📋 GitHub Actions Workflows

## 🔄 **Fluxo de Deploy**

### **Método 1: Repository Dispatch (Recomendado)**
1. **Repos Backend/Frontend** → Build & Push Docker image
2. **Repos Backend/Frontend** → Trigger `repository_dispatch` para `infrastructure` repo
3. **Infrastructure repo** → Recebe dispatch → Executa deploy via `ci-cd.yml`

### **Método 2: Docker Hub Webhook (Alternativo)**
1. **Repos Backend/Frontend** → Build & Push Docker image
2. **Docker Hub** → Webhook direto para `infrastructure` repo
3. **Infrastructure repo** → `docker-webhook.yml` → Trigger `ci-cd.yml`

> 💡 **Nota**: Use apenas um dos métodos para evitar deploys duplicados.

## 📁 **Workflows Ativos**

| Workflow | Trigger | Objetivo |
|----------|---------|----------|
| `ci-cd.yml` | `repository_dispatch`, `workflow_dispatch` | Deploy principal da infraestrutura |
| `deploy-dev.yml` | `repository_dispatch` | Deploy específico para ambiente dev |
| `build-database.yml` | `push`, `workflow_dispatch` | Build da imagem Docker do database |
| `test.yml` | `pull_request` | Testes rápidos de validação |
| `security-worflow.yml` | `push`, `schedule`, `workflow_dispatch` | Pipeline de segurança |
| `notify-pr.yml` | `pull_request` | Notificações Discord para PRs |
| `discord-notify-extended.yml` | `workflow_run`, `issues`, etc. | Notificações Discord consolidadas |

## 🔀 **Repository Dispatch Types**

### **Triggers Aceitos pelo `ci-cd.yml`:**
- `deploy-dev-frontend`
- `deploy-prod-frontend` 
- `deploy-dev-backend`
- `deploy-prod-backend`
- `deploy-manual`
- `docker-hub-auto-deploy`

### **Exemplo de Payload:**
```json
{
  "event_type": "deploy-dev-frontend",
  "client_payload": {
    "environment": "dev",
    "image_tag": "latest",
    "triggered_by": "frontend-repo"
  }
}
```

## 🛠️ **Configuração nos Repos Backend/Frontend**

Para usar `repository_dispatch`, adicione no final do workflow de build:

```yaml
- name: Trigger Infrastructure Deploy
  run: |
    curl -X POST \
      -H "Accept: application/vnd.github.v3+json" \
      -H "Authorization: token ${{ secrets.INFRASTRUCTURE_TOKEN }}" \
      "https://api.github.com/repos/AGES-Pro-Mata/infrastructure/dispatches" \
      -d '{
        "event_type": "deploy-dev-frontend",
        "client_payload": {
          "environment": "dev",
          "image_tag": "latest",
          "triggered_by": "frontend-repo"
        }
      }'
```

## 🔐 **Secrets Necessários**

| Secret | Descrição | Usado em |
|--------|-----------|----------|
| `DISCORD_WEBHOOK_URL` | Webhook para notificações gerais | Múltiplos workflows |
| `DISCORD_WEBHOOK_URL_PR` | Webhook específico para PRs | `notify-pr.yml` |
| `DOCKER_USERNAME` | Docker Hub username | `build-database.yml` |
| `DOCKER_PASSWORD` | Docker Hub password | `build-database.yml` |
| `AZURE_CREDENTIALS` | Credenciais Azure | Deploy workflows |
| `INFRASTRUCTURE_TOKEN` | Token para repository_dispatch | Repos externos |
