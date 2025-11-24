# Environment Variables

Este diretório contém **apenas exemplos** de variáveis de ambiente.

## Arquivos

### Para Desenvolvimento Local

**[local.env.example](local.env.example)**

- Copie para `.env` na raiz do projeto
- Configure variáveis para desenvolvimento local
- Docker Compose usará automaticamente

```bash
cp envs/local.env.example .env
vim .env  # Editar com suas variáveis
docker-compose up -d
```

### Para Produção (Referência)

**[production.env.example](production.env.example)**

- Referência de variáveis necessárias em produção
- **NÃO** commitar valores reais
- Use **GitHub Secrets** para valores sensíveis

## ⚠️ Segurança

### ✅ Valores Permitidos (podem ser commitados)

- Nomes de domínio
- Nomes de usuário de banco (não-sensíveis)
- Configurações públicas

### ❌ NUNCA Commitar

- Senhas
- Tokens API
- Secrets JWT
- Chaves privadas
- Qualquer credencial

## Produção: Use GitHub Secrets

Todas as variáveis sensíveis devem ser configuradas em:

**Settings → Secrets and variables → Actions → New repository secret**

Exemplo:

```plaintext
POSTGRES_PASSWORD=<senha-forte>
JWT_SECRET=<secret-256-bits>
AWS_ACCESS_KEY_ID=<aws-key>
```

Usamos apenas:

- ✅ `.env.example` para referência
- ✅ GitHub Secrets para produção
- ✅ `.env` local (gitignored)
