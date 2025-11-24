# Gerenciamento de Usuários - PRO-MATA

## Criar Usuário Admin

```bash
docker-compose exec backend npm run cli user:create \
  --email admin@promata.com.br \
  --password <SenhaSegura123!> \
  --role ADMIN \
  --name "Administrator"
```

## Criar Usuário Comum

```bash
docker-compose exec backend npm run cli user:create \
  --email usuario@exemplo.com \
  --password <Senha123!> \
  --role USER \
  --name "Nome do Usuário"
```

## Listar Usuários

```bash
docker-compose exec backend npm run cli user:list
```

## Atualizar Papel (Role)

```bash
docker-compose exec backend npm run cli user:update-role \
  --email usuario@exemplo.com \
  --role ADMIN
```

## Resetar Senha

```bash
docker-compose exec backend npm run cli user:reset-password \
  --email usuario@exemplo.com \
  --password <NovaSenha123!>
```

## Desativar Usuário

```bash
docker-compose exec backend npm run cli user:deactivate \
  --email usuario@exemplo.com
```

## Reativar Usuário

```bash
docker-compose exec backend npm run cli user:activate \
  --email usuario@exemplo.com
```

## Deletar Usuário

```bash
docker-compose exec backend npm run cli user:delete \
  --email usuario@exemplo.com \
  --confirm
```

## Acesso Direto ao Banco

### Via Prisma Studio (Dev)

```bash
docker-compose -f docker-compose.yml -f docker-compose.dev.yml up -d prisma-studio
```

Acesse: <http://localhost:5555>

### Via psql

```bash
docker-compose exec postgres psql -U promata

# Listar usuários
SELECT id, email, role, created_at FROM "app"."User";

# Atualizar senha (hash bcrypt)
UPDATE "app"."User" SET password = '<hash>' WHERE email = 'usuario@exemplo.com';
```

## Roles Disponíveis

- **ADMIN**: Acesso total
- **USER**: Acesso padrão
- **GUEST**: Acesso limitado (read-only)

## Políticas de Senha

- Mínimo: 8 caracteres
- Deve conter:
  - Letra maiúscula
  - Letra minúscula
  - Número
  - Caractere especial (!@#$%^&*)
