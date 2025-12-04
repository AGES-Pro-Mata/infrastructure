# Gerenciamento de Seed e Usuários - Pro-Mata

Este documento explica como funciona o seed inicial do banco de dados e como gerenciar usuários administrativos no sistema Pro-Mata.

## Introdução

O sistema Pro-Mata cria automaticamente um usuário ROOT na primeira vez que o banco de dados é iniciado. Este processo é totalmente automático e não requer intervenção manual.

## Como Funciona o Seed Automático

### Execução Automática

O PostgreSQL executa automaticamente todos os scripts SQL em `/docker-entrypoint-initdb.d/` quando o container é iniciado pela **primeira vez** com um volume de dados vazio.

**Localização do seed**:
```
docker/database/scripts/init/03-seed-client.sql
```

**Ordem de execução**:
1. `01-create-schemas.sh` - Cria schemas (app, umami, metabase)
2. `02-extensions.sh` - Instala extensões PostgreSQL
3. `03-seed-client.sql` - Cria usuário ROOT padrão ← **SEED**

### Usuário ROOT Criado

O seed cria automaticamente:

- **Role**: ROOT (acesso total ao sistema)
- **Status**: Ativo
- **Email e Senha**: Fornecidos ao administrador via mensagem privada

### ⚠️ Importante: Segurança

**ALTERE A SENHA NO PRIMEIRO LOGIN!**

Por questões de segurança, você deve alterar a senha imediatamente após fazer login pela primeira vez.

### Como Alterar a Senha no Primeiro Login

1. Acesse o sistema: `https://promata.com.br`
2. Faça login com as credenciais fornecidas
3. Navegue para: **Perfil → Configurações → Segurança**
4. Clique em **Alterar Senha**
5. Defina uma senha forte (mínimo 12 caracteres, incluindo maiúsculas, minúsculas, números e símbolos)

---

## Modificar o Seed Antes do Deploy

Se você precisa modificar o usuário ROOT antes do primeiro deploy, edite o arquivo de seed.

### Editar Usuário ROOT Padrão

**Arquivo**: `docker/database/scripts/init/03-seed-client.sql`

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
    'seu.email@example.com',           -- Modificar email
    '$2b$10$HASH_BCRYPT_AQUI',          -- Modificar hash da senha
    'Seu Nome Completo',                -- Modificar nome
    'ROOT',
    true,
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;
```

---

## Gerar Hash BCrypt de Senha

Para criar ou modificar usuários, você precisa gerar o hash BCrypt da senha.

### Método 1: Via npx (Recomendado - Sem Instalação)

```bash
# Gerar hash sem instalar nada
npx --yes bcryptjs-cli hash 'MinhaS3nh@Forte' 10

# Saída (exemplo):
# $2b$10$XyZ123AbC456DeF789GhI0JkLmNoPqRsTuVwXyZ123AbC456DeF789
```

### Método 2: Via Node.js

```bash
# Instalar bcrypt temporariamente
npm install -g bcrypt

# Gerar hash
node -e "console.log(require('bcrypt').hashSync('MinhaS3nh@Forte', 10))"
```

### Método 3: Ferramenta Online (Apenas para Testes)

1. Acesse: <https://bcrypt-generator.com/>
2. Digite sua senha
3. Selecione **Rounds**: `10`
4. Clique em **Generate**
5. Copie o hash gerado

⚠️ **Atenção**: Use ferramentas online apenas para senhas de teste. Para produção, use métodos 1 ou 2.

---

## Adicionar Novos Usuários ao Seed

Se você precisa que o sistema crie múltiplos administradores automaticamente no primeiro deploy, adicione-os ao arquivo de seed.

### Passo a Passo

#### 1. Gerar Hash da Senha

```bash
npx --yes bcryptjs-cli hash 'SenhaDoNovoAdmin' 10
```

#### 2. Adicionar ao Arquivo de Seed

Edite `docker/database/scripts/init/03-seed-client.sql` e adicione:

```sql
-- Adicionar novo administrador
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
    'novo.admin@example.com',
    '$2b$10$XyZ123AbC456DeF789GhI0JkLmNoPqRsTuVwXyZ123AbC456DeF789',
    'Nome do Novo Admin',
    'ADMIN',  -- ROOT, ADMIN, COORDINATOR, STAFF, ou USER
    true,
    NOW(),
    NOW()
)
ON CONFLICT (email) DO NOTHING;
```

---

## Executar Seed Manualmente (Banco Já Existente)

Se o banco de dados já foi criado e você quer executar a seed novamente, siga estes passos:

### Via Docker Compose

```bash
# SSH para o servidor
ssh ubuntu@<EC2_IP>

# Copiar seed atualizada
scp docker/database/scripts/init/03-seed-client.sql ubuntu@<EC2_IP>:/tmp/seed.sql

# Executar seed no banco
docker-compose exec -T postgres psql -U promata -d promata < /tmp/seed.sql

# Verificar usuários criados
docker-compose exec postgres psql -U promata -d promata -c \
  "SELECT email, name, role FROM app.\"User\";"
```

---

## Gerenciar Usuários via Interface Web

Após fazer login como ROOT, você pode adicionar, editar e remover usuários diretamente pela interface web.

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
   - **Nome**: Nome completo
   - **Email**: Email válido (usado para login)
   - **Senha**: Senha inicial (mínimo 8 caracteres)
   - **Role**: Nível de acesso
   - **Status**: Ativo/Inativo
3. Clique em **Salvar**
4. O usuário receberá um email com instruções de primeiro acesso

---

## Roles Disponíveis

O sistema Pro-Mata possui 5 níveis de acesso com permissões diferentes:

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

## Troubleshooting

### Problema: Seed não foi executada

**Sintoma**: Não consigo fazer login, usuário ROOT não existe

**Causas possíveis**:
1. Volume do PostgreSQL já existia antes
2. Seed foi executada mas deu erro

**Soluções**:

**Verificar se seed foi executada**:
```bash
# SSH para servidor
ssh ubuntu@<EC2_IP>

# Verificar logs do postgres
docker-compose logs postgres | grep "seed"

# Verificar se usuário existe
docker-compose exec postgres psql -U promata -d promata -c \
  "SELECT email, name, role FROM app.\"User\";"
```

**Se seed não foi executada**:
```bash
# Executar manualmente
docker-compose exec -T postgres psql -U promata -d promata < \
  docker/database/scripts/init/03-seed-client.sql
```

### Problema: Usuário já existe

**Erro:**
```plaintext
ERROR: duplicate key value violates unique constraint "User_email_key"
```

**Solução:**
O email já está cadastrado. Isso é esperado - o `ON CONFLICT DO NOTHING` previne duplicatas. Não é um erro crítico.

### Problema: Hash BCrypt inválido

**Erro:**
```plaintext
ERROR: invalid BCrypt hash format
```

**Solução:**
Verifique se o hash:
- Começa com `$2b$10$` ou `$2a$10$`
- Tem exatamente 60 caracteres
- Foi copiado corretamente (sem espaços ou quebras de linha)

Gere um novo hash usando os métodos descritos acima.

---

## Recriando o Banco de Dados (Reset Completo)

⚠️ **ATENÇÃO**: Isso apaga TODOS OS DADOS!

Se você precisa recomeçar do zero:

```bash
# SSH para servidor
ssh ubuntu@<EC2_IP>

# Parar containers
cd /opt/promata
docker-compose down

# DELETAR volume do postgres (APAGA TUDO!)
docker volume rm promata_postgres_data

# Subir novamente (seed será executada automaticamente)
docker-compose up -d

# Aguardar postgres ficar healthy
docker-compose logs -f postgres
```

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

- Nunca commite senhas ou hashes reais em repositórios públicos
- Não use senhas fracas como "123456", "admin", "password"
- Não use ferramentas online não confiáveis para gerar hashes de senhas de produção
- Seed só executa automaticamente na primeira inicialização - modificações posteriores requerem execução manual

---

## Suporte

Para questões sobre gerenciamento de usuários ou seed:

1. Consulte a documentação adicional em [USER_MANAGEMENT.md](USER_MANAGEMENT.md)
2. Verifique os logs do postgres: `docker-compose logs postgres`
3. Entre em contato com a equipe de desenvolvimento AGES/PUCRS

---

**Pro-Mata** - Plataforma de Reservas para Centro de Pesquisas
