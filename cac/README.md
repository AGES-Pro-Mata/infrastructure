# Configuration as Code (Ansible)

Playbooks Ansible para configuração inicial dos servidores.

## Uso

### 1. Configurar Inventory

```bash
cd cac/inventory
cp hosts.yml.example hosts.yml
cp group_vars/all.yml.example group_vars/all.yml

# Editar com IPs reais
vim hosts.yml
```

### 2. Deploy Single-Node

```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-complete-stack.yml \
  --limit single_node
```

### 3. Deploy Multi-Node (Swarm)

```bash
# Deploy manager + workers
ansible-playbook -i inventory/hosts.yml playbooks/deploy-complete-stack.yml
```

## Estrutura

```
cac/
├── inventory/
│   ├── hosts.yml.example          # Inventory exemplo
│   └── group_vars/
│       └── all.yml.example        # Variáveis exemplo
├── playbooks/
│   ├── deploy-complete-stack.yml  # Deploy completo
│   └── ...
├── templates/                      # Templates Jinja2
└── requirements.yml                # Dependências Ansible
```

## ⚠️ Importante

- **Nunca commitar** `inventory/hosts.yml` ou `group_vars/all.yml` com valores reais
- Use **variáveis de ambiente** para valores sensíveis
- Prefira **GitHub Actions** para deploys automatizados
- Ansible é usado apenas para **setup inicial** do servidor

## Migração para GitHub Actions

A maioria dos deploys agora usa GitHub Actions:

- **Infraestrutura**: [.github/workflows/infra-aws.yml](../.github/workflows/infra-aws.yml)
- **Backend**: [.github/workflows/deploy-backend.yml](../.github/workflows/deploy-backend.yml)
- **Frontend**: [.github/workflows/deploy-frontend.yml](../.github/workflows/deploy-frontend.yml)

Ansible é mantido para:
- Setup inicial de VMs
- Configurações de sistema operacional
- Deploys manuais quando necessário
