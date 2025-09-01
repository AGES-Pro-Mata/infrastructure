#!/bin/bash

# Script para testar as notificações estendidas do Discord
# Usage: ./test-extended-notifications.sh <WEBHOOK_URL>

WEBHOOK_URL="${1:-$DISCORD_WEBHOOK_URL}"

if [[ -z "$WEBHOOK_URL" ]]; then
    echo "❌ Erro: URL do webhook não fornecida"
    echo "Usage: $0 <WEBHOOK_URL>"
    echo "Ou configure a variável DISCORD_WEBHOOK_URL"
    exit 1
fi

echo "🧪 Testando Discord Extended Notifications..."
echo "URL: ${WEBHOOK_URL:0:50}..."
echo ""

# Função para fazer request e verificar resposta
send_notification() {
    local test_name="$1"
    local payload="$2"
    
    echo -n "📤 $test_name: "
    
    response=$(curl -s -w "%{http_code}" -X POST "$WEBHOOK_URL" \
        -H "Content-Type: application/json" \
        -d "$payload")
    
    http_code="${response: -3}"
    if [[ "$http_code" == "204" ]]; then
        echo "✅ Sucesso"
    else
        echo "❌ Falha (HTTP $http_code)"
        echo "   Response: ${response%???}"
    fi
    
    sleep 2  # Rate limit prevention
}

# Teste 1: Review Aprovado
echo "🔍 Testando notificações de REVIEW..."
send_notification "Review Aprovado" '{
    "embeds": [
        {
            "title": "✅ Review: feat: adiciona sistema de autenticação",
            "url": "https://github.com/pro-mata/frontend/pull/42",
            "description": "LucasLanti aprovou este PR",
            "color": 65280,
            "fields": [
                {
                    "name": "Repositório",
                    "value": "pro-mata/frontend",
                    "inline": true
                },
                {
                    "name": "Reviewer",
                    "value": "LucasLanti",
                    "inline": true
                }
            ],
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }
    ]
}'

# Teste 2: Review Changes Requested
send_notification "Review Changes Requested" '{
    "embeds": [
        {
            "title": "🔄 Review: fix: corrige validação de formulário",
            "url": "https://github.com/pro-mata/backend/pull/18",
            "description": "TechLead solicitou alterações em este PR",
            "color": 16776960,
            "fields": [
                {
                    "name": "Repositório",
                    "value": "pro-mata/backend",
                    "inline": true
                },
                {
                    "name": "Reviewer",
                    "value": "TechLead",
                    "inline": true
                }
            ],
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }
    ]
}'

echo ""
echo "🐛 Testando notificações de ISSUES..."

# Teste 3: Nova Issue
send_notification "Nova Issue" '{
    "embeds": [
        {
            "title": "🐛 Bug no sistema de reservas",
            "url": "https://github.com/pro-mata/frontend/issues/15",
            "description": "Nova issue criada por UsuarioTeste",
            "color": 16776960,
            "fields": [
                {
                    "name": "Repositório",
                    "value": "pro-mata/frontend",
                    "inline": true
                },
                {
                    "name": "Autor",
                    "value": "UsuarioTeste",
                    "inline": true
                }
            ],
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }
    ]
}'

# Teste 4: Issue Resolvida
send_notification "Issue Resolvida" '{
    "embeds": [
        {
            "title": "✅ Problema de performance no dashboard",
            "url": "https://github.com/pro-mata/backend/issues/23",
            "description": "Issue resolvida por DevTeam",
            "color": 65280,
            "fields": [
                {
                    "name": "Repositório",
                    "value": "pro-mata/backend",
                    "inline": true
                },
                {
                    "name": "Autor",
                    "value": "DevTeam",
                    "inline": true
                }
            ],
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }
    ]
}'

echo ""
echo "🚀 Testando notificações de DEPLOY..."

# Teste 5: Deploy Sucesso Development
send_notification "Deploy Success (Dev)" '{
    "embeds": [
        {
            "title": "🚀 Deploy Realizado com Sucesso!",
            "url": "https://github.com/pro-mata/frontend/actions/runs/123456",
            "description": "Workflow **pro-mata/frontend** executado com sucesso",
            "color": 65280,
            "fields": [
                {
                    "name": "Workflow",
                    "value": "Frontend CI/CD Pipeline",
                    "inline": true
                },
                {
                    "name": "Branch",
                    "value": "develop",
                    "inline": true
                },
                {
                    "name": "Status",
                    "value": "success",
                    "inline": true
                },
                {
                    "name": "Ambiente",
                    "value": "Development (Azure)",
                    "inline": true
                },
                {
                    "name": "URL",
                    "value": "[Acessar aplicação](https://dev.promata.com.br)",
                    "inline": false
                }
            ],
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }
    ]
}'

# Teste 6: Deploy Falha Production (com mention)
send_notification "Deploy Failure (Prod)" '{
    "content": "<@&1399565960922402929><@&1399580242636701726> **pro-mata/backend**",
    "embeds": [
        {
            "title": "🚨 Deploy Falhou!",
            "url": "https://github.com/pro-mata/backend/actions/runs/789012",
            "description": "Workflow **pro-mata/backend** falhou",
            "color": 16711680,
            "fields": [
                {
                    "name": "Workflow",
                    "value": "Deploy Production",
                    "inline": true
                },
                {
                    "name": "Branch",
                    "value": "main",
                    "inline": true
                },
                {
                    "name": "Status",
                    "value": "failure",
                    "inline": true
                },
                {
                    "name": "Ambiente",
                    "value": "Production (AWS)",
                    "inline": true
                }
            ],
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }
    ]
}'

echo ""
echo "📋 Testando notificação de PR CLOSED/MERGED..."

# Teste 7: PR Merged
send_notification "PR Merged" '{
    "embeds": [
        {
            "title": "✅ feat: implementa sistema de autenticação",
            "url": "https://github.com/pro-mata/frontend/pull/42",
            "description": "PR foi aprovado e integrado por LucasLanti",
            "color": 65280,
            "fields": [
                {
                    "name": "Repositório",
                    "value": "pro-mata/frontend",
                    "inline": true
                },
                {
                    "name": "Status",
                    "value": "PR Merged com Sucesso!",
                    "inline": true
                },
                {
                    "name": "Branch",
                    "value": "feature/auth → develop",
                    "inline": false
                }
            ],
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }
    ]
}'

# Teste 8: PR Fechado sem Merge
send_notification "PR Closed" '{
    "embeds": [
        {
            "title": "❌ fix: tentativa de correção que não funcionou",
            "url": "https://github.com/pro-mata/backend/pull/18",
            "description": "PR foi fechado sem integração por Developer",
            "color": 16711680,
            "fields": [
                {
                    "name": "Repositório",
                    "value": "pro-mata/backend",
                    "inline": true
                },
                {
                    "name": "Status",
                    "value": "PR Fechado sem Merge",
                    "inline": true
                },
                {
                    "name": "Branch",
                    "value": "bugfix/broken-feature → main",
                    "inline": false
                }
            ],
            "timestamp": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
        }
    ]
}'

echo ""
echo "🎯 Resumo dos Testes (SEM duplicar o notify-pr.yml):"
echo "✅ Reviews (aprovado/changes requested/comentários)"
echo "✅ Issues (abertura/fechamento)"  
echo "✅ PR Status (closed/merged - complementa o opened do colega)"
echo "✅ Workflows/Deploy (sucesso/falha com ambiente)"
echo ""
echo "🔍 Verificações no Discord:"
echo "1. Notificações complementares apareceram junto com as do notify-pr.yml?"
echo "2. Não há duplicação de PR opened (só o arquivo do colega deve notificar)?"
echo "3. Reviews e deploys estão sendo notificados?"
echo "4. As mentions aparecem só em falhas críticas?"
echo ""
echo "📋 Testes reais recomendados:"
echo "1. Abra um PR (deve notificar via notify-pr.yml do colega)"
echo "2. Faça review nesse PR (deve notificar via extended)"
echo "3. Merge o PR (deve notificar merge via extended)"
echo "4. Crie/feche issue (deve notificar via extended)"
echo "5. Faça deploy (deve notificar workflow via extended)"
echo ""
echo "💡 Agora são DOIS workflows trabalhando juntos:"
echo "   📝 notify-pr.yml: PR opened/reopened/ready_for_review"
echo "   ⚙️ extended: Reviews, Issues, PR status, Workflows"