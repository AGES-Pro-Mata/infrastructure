# Gerenciamento de Seed e Usuários - Pro-Mata

Este documento explica como gerenciar o seed inicial do banco de dados e configurar usuários administrativos no sistema Pro-Mata.

## Introdução

O sistema Pro-Mata vem pré-configurado com um usuário ROOT padrão que é criado automaticamente na primeira execução. Este usuário permite que o administrador do sistema acesse a plataforma imediatamente após o deploy e configure outros usuários conforme necessário.

## Usuário Padrão Pré-Configurado

O sistema inclui um seed inicial localizado em:

```plaintext
docker/database/scripts/seed-client.sql
```

Este arquivo cria automaticamente um usuário ROOT com:

- **Role**: ROOT (acesso total ao sistema)
- **Status**: Ativo

**As credenciais de acesso serão fornecidas diretamente ao administrador do sistema.**

### ⚠️ Importante: Segurança

**ALTERE A SENHA NO PRIMEIRO LOGIN!**

Por questões de segurança, você deve alterar a senha imediatamente após fazer login pela primeira vez.

### Como Alterar a Senha no Primeiro Login

1. Acesse o sistema: `https://promata.com.br`
2. Faça login com as credenciais fornecidas
3. Navegue para: **Perfil → Configurações → Segurança**
4. Clique em **Alterar Senha**
5. Defina uma senha forte (mínimo 8 caracteres, incluindo maiúsculas, minúsculas, números e símbolos)

---

## Como Modificar Usuários na Seed

Se você precisa adicionar novos usuários administrativos diretamente via seed (antes do primeiro deploy ou para resetar usuários), siga os passos abaixo.

### Adicionar Novos Usuários Administrativos

#### 1. Editar o Arquivo de Seed

O arquivo de seed está localizado em:

```plaintext
docker/database/scripts/seed-client.sql
```

#### 2. Adicionar Novo INSERT

No final do arquivo, descomente e modifique o bloco de exemplo:

```sql
INSERT INTO "User" (
    id,
    email,
    password,
    name,
    role,
    "isActive",
    "createdAt",
    "updatedAt"
) VALUES (
    gen_random_uuid(),
    'novo.admin@example.com',           -- Email do novo usuário
    '$2b$10$HASH_BCRYPT_AQUI',            -- Hash BCrypt da senha
    'Nome do Administrador',             -- Nome completo
    'ADMIN',                             -- Role (ROOT, ADMIN, COORDINATOR, STAFF, USER)
    true,
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;
```

#### 3. Explicação dos Campos

| Campo | Descrição | Exemplo |
|-------|-----------|---------|
| `id` | UUID único (gerado automaticamente) | `gen_random_uuid()` |
| `email` | Email do usuário (único no sistema) | `admin@example.com` |
| `password` | Hash BCrypt da senha (cost=10) | `$2b$10$...` |
| `name` | Nome completo do usuário | `João Silva` |
| `role` | Nível de acesso (ver tabela abaixo) | `ADMIN` |
| `isActive` | Se o usuário está ativo | `true` ou `false` |
| `createdAt` | Data de criação (automática) | `NOW()` |
| `updatedAt` | Data de atualização (automática) | `NOW()` |

---

## Gerar Hash BCrypt de Senha

Para adicionar novos usuários, você precisa gerar o hash BCrypt da senha. Existem três métodos:

### Método 1: Via Backend CLI (Recomendado)

Se você já tem o sistema rodando, use o CLI do backend:

```bash
# SSH para o servidor
ssh ubuntu@<EC2_IP>

# Acessar diretório do projeto
cd /opt/promata

# Gerar hash de senha
docker-compose exec backend npm run cli password:hash

# Exemplo de saída:
# Digite a senha: MinhaS3nh@Forte
# Hash BCrypt: $2b$10$XyZ123AbC456DeF789GhI0JkLmNoPqRsTuVwXyZ123AbC456DeF789
```

### Método 2: Via Node.js Direto

Se você tem Node.js instalado localmente:

```bash
# Instalar bcrypt temporariamente
npm install -g bcrypt

# Gerar hash
node -e "console.log(require('bcrypt').hashSync('MinhaS3nh@Forte', 10))"

# Saída (exemplo):
# $2b$10$XyZ123AbC456DeF789GhI0JkLmNoPqRsTuVwXyZ123AbC456DeF789
```

### Método 3: Via npx (Sem Instalação)

```bash
# Gerar hash sem instalar nada
npx --yes bcryptjs-cli hash 'MinhaS3nh@Forte' 10

# Saída (exemplo):
# $2b$10$XyZ123AbC456DeF789GhI0JkLmNoPqRsTuVwXyZ123AbC456DeF789
```

### Método 4: Ferramenta Online

Use uma ferramenta online confiável:

1. Acesse: <https://bcrypt-generator.com/>
2. Digite sua senha (exemplo: `MinhaS3nh@Forte`)
3. Selecione **Rounds**: `10`
4. Clique em **Generate**
5. Copie o hash gerado

⚠️ **Atenção**: Use ferramentas online apenas para senhas de teste. Para senhas de produção, prefira os métodos 1, 2 ou 3.

---

## Aplicar Nova Seed

Após modificar o arquivo `seed-client.sql`, você precisa aplicá-lo ao banco de dados.

### Passo 1: Copiar Seed Atualizada para o Servidor

```bash
# De sua máquina local, copie o arquivo via SCP
scp docker/database/scripts/seed-client.sql ubuntu@<EC2_IP>:/tmp/seed-client.sql

# Exemplo com IP real:
scp docker/database/scripts/seed-client.sql ubuntu@54.207.123.45:/tmp/seed-client.sql
```

### Passo 2: Executar SQL no Container PostgreSQL

```bash
# SSH para o servidor
ssh ubuntu@<EC2_IP>

# Acessar diretório do projeto
cd /opt/promata

# Executar seed no banco de dados
docker-compose exec -T postgres psql -U promata -d promata < /tmp/seed-client.sql

# Limpar arquivo temporário
rm /tmp/seed-client.sql
```

### Exemplo Completo

```bash
# 1. Copiar arquivo
scp docker/database/scripts/seed-client.sql ubuntu@54.207.123.45:/tmp/seed-client.sql

# 2. SSH para servidor
ssh ubuntu@54.207.123.45

# 3. Executar seed
cd /opt/promata
docker-compose exec -T postgres psql -U promata -d promata < /tmp/seed-client.sql

# 4. Verificar usuários criados
docker-compose exec postgres psql -U promata -d promata -c "SELECT email, name, role FROM app.\"User\";"

# Saída esperada:
#           email              |        name         | role
# ----------------------------+---------------------+------
#  augusto.alvim@pucrs.br     | Augusto Mussi Alvim | ROOT
#  novo.admin@example.com     | João Silva          | ADMIN
```

---

## Gerenciar Usuários via Interface Web

Após fazer login como ROOT, você pode adicionar, editar e remover usuários diretamente pela interface web, sem necessidade de editar SQL manualmente.

### Acessar Gerenciamento de Usuários

1. Faça login no sistema: `https://promata.com.br`
2. Clique no menu superior direito (ícone de perfil)
3. Navegue para: **Configurações → Usuários**
4. Aqui você pode:
   - ✅ Adicionar novos usuários
   - ✏️ Editar usuários existentes
   - 🗑️ Desativar/remover usuários
   - 🔑 Resetar senhas

### Adicionar Usuário via Interface

1. Clique em **+ Novo Usuário**
2. Preencha o formulário:
   - **Nome**: Nome completo do usuário
   - **Email**: Email válido (será usado para login)
   - **Senha**: Senha inicial (mínimo 8 caracteres)
   - **Role**: Selecione o nível de acesso
   - **Status**: Ativo/Inativo
3. Clique em **Salvar**
4. O usuário receberá um email com instruções de primeiro acesso

---

## Roles Disponíveis

O sistema Pro-Mata possui 5 níveis de acesso (roles) com permissões diferentes:

| Role | Descrição | Permissões |
|------|-----------|------------|
| **ROOT** | Acesso total ao sistema | • Gerenciar usuários<br>• Configurar sistema<br>• Acesso a todos os módulos<br>• Visualizar analytics e BI |
| **ADMIN** | Administrador de conteúdo | • Gerenciar reservas<br>• Gerenciar conteúdo<br>• Aprovar/rejeitar solicitações<br>• Visualizar relatórios |
| **COORDINATOR** | Coordenador de atividades | • Coordenar eventos<br>• Gerenciar calendário<br>• Visualizar reservas<br>• Criar atividades |
| **STAFF** | Funcionário | • Visualizar reservas<br>• Atualizar status de atividades<br>• Acesso limitado a relatórios |
| **USER** | Usuário comum | • Fazer reservas<br>• Visualizar calendário<br>• Gerenciar próprio perfil |

### Escolher a Role Apropriada

- Use **ROOT** apenas para o administrador principal do sistema
- Use **ADMIN** para gestores que precisam controlar reservas e conteúdo
- Use **COORDINATOR** para coordenadores de atividades e eventos
- Use **STAFF** para funcionários operacionais
- Use **USER** para visitantes e pesquisadores que fazem reservas

---

## Exemplo Completo: Adicionar Novo Administrador

### Cenário

Você quer adicionar Maria Santos como administradora do sistema.

### Passo a Passo

#### 1. Gerar hash da senha

```bash
# Via npx (recomendado - sem instalação)
npx --yes bcryptjs-cli hash 'Maria@2025!' 10

# Resultado (exemplo):
# $2b$10$XyZ123AbC456DeF789GhI0JkLmNoPqRsTuVwXyZ123AbC456DeF789
```

#### 2. Editar seed-client.sql

Adicione no arquivo `docker/database/scripts/seed-client.sql`:

```sql
-- Adicionar Maria Santos como ADMIN
INSERT INTO "User" (
    id,
    email,
    password,
    name,
    role,
    "isActive",
    "createdAt",
    "updatedAt"
) VALUES (
    gen_random_uuid(),
    'maria.santos@example.com',
    '$2b$10$XyZ123AbC456DeF789GhI0JkLmNoPqRsTuVwXyZ123AbC456DeF789',
    'Maria Santos',
    'ADMIN',
    true,
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;
```

#### 3. Aplicar ao servidor

```bash
# Copiar arquivo
scp docker/database/scripts/seed-client.sql ubuntu@54.207.123.45:/tmp/seed-client.sql

# SSH e aplicar
ssh ubuntu@54.207.123.45
cd /opt/promata
docker-compose exec -T postgres psql -U promata -d promata < /tmp/seed-client.sql

# Verificar
docker-compose exec postgres psql -U promata -d promata -c \
  "SELECT email, name, role FROM app.\"User\" WHERE email = 'maria.santos@example.com';"
```

#### 4. Testar login

1. Acesse: `https://promata.com.br`
2. Faça login com:
   - Email: `maria.santos@example.com`
   - Senha: `Maria@2025!`
3. Solicite que Maria altere a senha no primeiro login

---

## Troubleshooting

### Problema: Usuário já existe

**Erro:**

```plaintext
ERROR: duplicate key value violates unique constraint "User_email_key"
```

**Solução:**
O email já está cadastrado. Use o `ON CONFLICT (email) DO NOTHING` no INSERT ou escolha outro email.

### Problema: Hash BCrypt inválido

**Erro:**

```plaintext
ERROR: invalid BCrypt hash format
```

**Solução:**
Verifique se o hash começa com `$2b$10$` e tem exatamente 60 caracteres. Gere um novo hash usando um dos métodos descritos.

### Problema: Seed não foi aplicada

**Verificação:**

```bash
# Verificar se usuário existe
docker-compose exec postgres psql -U promata -d promata -c \
  "SELECT email, name, role FROM app.\"User\";"
```

**Solução:**
Certifique-se de que:

1. O schema está correto: `SET search_path TO app, public;`
2. A tabela existe: `\dt app.*` no psql
3. O arquivo foi executado sem erros

---

## Segurança e Boas Práticas

### ✅ Recomendações

- Sempre use senhas fortes (mínimo 12 caracteres, com maiúsculas, minúsculas, números e símbolos)
- Altere a senha padrão imediatamente após o primeiro login
- Não compartilhe senhas entre usuários
- Use roles apropriadas (não dê acesso ROOT desnecessariamente)
- Desative usuários inativos ao invés de deletá-los
- Faça backup regular do banco de dados antes de modificar seeds

### ⚠️ Avisos

- Nunca commite senhas ou hashes em repositórios públicos
- Não use senhas fracas como "123456", "admin", "password"
- Não use ferramentas online não confiáveis para gerar hashes de senhas de produção
- Não execute seed em produção sem backup prévio

---

## Suporte

Para questões sobre gerenciamento de usuários ou seed:

1. Consulte a documentação adicional em [USER_MANAGEMENT.md](USER_MANAGEMENT.md)
2. Verifique os logs do backend: `docker-compose logs -f backend`
3. Entre em contato com a equipe de desenvolvimento AGES/PUCRS

---

**Pro-Mata** - Plataforma de Reservas para Centro de Pesquisas
