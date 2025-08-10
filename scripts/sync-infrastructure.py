#!/usr/bin/env python3
"""
Script completo de sincronização GitHub → GitLab AGES
Adaptado para repositório de infraestrutura Pro-Mata
Para uso no projeto Pro-Mata PUCRS
"""

import os
import sys
import json
import requests
import subprocess
from datetime import datetime, timezone
from typing import Dict, List, Optional

try:
    import gitlab
except ImportError:
    print("❌ Módulo 'python-gitlab' não encontrado. Instalando...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "python-gitlab"])
    import gitlab

class ProMataInfrastructureSyncer:
    def __init__(self):
        """Inicializa o sincronizador de infraestrutura"""
        self.git_token = os.environ.get('GIT_TOKEN')
        self.gitlab_url = os.environ.get('GITLAB_URL', 'https://tools.ages.pucrs.br')
        self.gitlab_token = os.environ.get('GITLAB_TOKEN')
        self.gitlab_project_id = os.environ.get('GITLAB_PROJECT_ID')
        self.repo_name = os.environ.get('GITHUB_REPOSITORY', 'AGES-Pro-Mata/infra')
        
        # Validar configurações
        if not all([self.git_token, self.gitlab_token, self.gitlab_project_id, self.repo_name]):
            self.log("❌ Configurações incompletas. Verifique os secrets:", "ERROR")
            self.log(f"   GIT_TOKEN: {'✓' if self.git_token else '✗'}", "ERROR")
            self.log(f"   GITLAB_TOKEN: {'✓' if self.gitlab_token else '✗'}", "ERROR")
            self.log(f"   GITLAB_PROJECT_ID: {'✓' if self.gitlab_project_id else '✗'}", "ERROR")
            self.log(f"   GITHUB_REPOSITORY: {self.repo_name}", "ERROR")
            raise ValueError("Configurações incompletas")
        
        # Clientes API
        try:
            self.gl = gitlab.Gitlab(self.gitlab_url, private_token=self.gitlab_token)
            self.gl.auth()
            self.project = self.gl.projects.get(self.gitlab_project_id)
            self.log(f"✅ Conectado ao GitLab: {self.project.path_with_namespace}")
        except Exception as e:
            self.log(f"❌ Erro ao conectar GitLab: {str(e)}", "ERROR")
            raise
        
        self.github_headers = {
            'Authorization': f'token {self.git_token}',
            'Accept': 'application/vnd.github.v3+json',
            'User-Agent': 'Pro-Mata-Infrastructure-Sync/1.0'
        }

    def log(self, message: str, level: str = "INFO"):
        """Log com timestamp e formatação para GitHub Actions"""
        timestamp = datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')
        
        # Emojis e cores por nível
        level_config = {
            "INFO": "ℹ️",
            "WARN": "⚠️", 
            "ERROR": "❌",
            "SUCCESS": "✅"
        }
        
        emoji = level_config.get(level, "ℹ️")
        print(f"[{timestamp}] {level}: {emoji} {message}")
        
        # Para GitHub Actions, usar commands específicos
        if level == "WARN":
            print(f"::warning::{message}")
        elif level == "ERROR":
            print(f"::error::{message}")
        elif level == "SUCCESS":
            print(f"::notice::{message}")

    def mirror_repository(self):
        """Espelha o repositório de infraestrutura para o GitLab"""
        self.log("🔄 Iniciando espelhamento do repositório de infraestrutura...")
        
        try:
            # Para repositório de infraestrutura, fazemos push direto
            git_commands = [
                ["git", "remote", "add", "gitlab", f"{self.gitlab_url}/pro-mata/infra.git"],
                ["git", "fetch", "--all"],
                ["git", "push", "--mirror", "gitlab"]
            ]
            
            for cmd in git_commands:
                try:
                    subprocess.run(cmd, check=True, capture_output=True, text=True)
                    self.log(f"✅ Comando executado: {' '.join(cmd)}")
                except subprocess.CalledProcessError as e:
                    if "already exists" in e.stderr:
                        self.log(f"⚠️ Remote já existe, continuando...")
                        continue
                    else:
                        self.log(f"❌ Erro no comando {' '.join(cmd)}: {e.stderr}", "ERROR")
                        
        except Exception as e:
            self.log(f"❌ Erro no espelhamento: {str(e)}", "ERROR")

    def setup_gitlab_labels(self):
        """Configura labels específicas para infraestrutura no GitLab"""
        self.log("🏷️ Configurando labels de infraestrutura no GitLab...")
        
        infra_labels = [
            # Labels básicas
            {'name': 'bug', 'color': '#d73a4a', 'description': 'Erro ou problema na infraestrutura'},
            {'name': 'enhancement', 'color': '#a2eeef', 'description': 'Nova funcionalidade ou melhoria'},
            {'name': 'documentation', 'color': '#0075ca', 'description': 'Relacionado à documentação'},
            
            # Labels de prioridade
            {'name': 'CRÍTICO', 'color': '#b60205', 'description': 'Problema crítico - produção afetada'},
            {'name': 'IMPORTANTE', 'color': '#d93f0b', 'description': 'Alta prioridade'},
            {'name': 'débito-técnico', 'color': '#fbca04', 'description': 'Débito técnico de infraestrutura'},
            
            # Labels de componentes
            {'name': 'terraform', 'color': '#5c4ee5', 'description': 'Relacionado ao Terraform'},
            {'name': 'ansible', 'color': '#ee0000', 'description': 'Relacionado ao Ansible'},
            {'name': 'docker', 'color': '#2496ed', 'description': 'Relacionado ao Docker/containers'},
            {'name': 'kubernetes', 'color': '#326ce5', 'description': 'Relacionado ao Kubernetes'},
            {'name': 'ci-cd', 'color': '#28a745', 'description': 'CI/CD e pipelines'},
            
            # Labels de ambiente
            {'name': 'desenvolvimento', 'color': '#1d76db', 'description': 'Ambiente de desenvolvimento'},
            {'name': 'staging', 'color': '#0e8a16', 'description': 'Ambiente de staging'},
            {'name': 'produção', 'color': '#b60205', 'description': 'Ambiente de produção'},
            
            # Labels de cloud
            {'name': 'azure', 'color': '#0078d4', 'description': 'Microsoft Azure'},
            {'name': 'aws', 'color': '#ff9900', 'description': 'Amazon Web Services'},
            {'name': 'monitoramento', 'color': '#7057ff', 'description': 'Monitoramento e observabilidade'},
            
            # Labels de processo
            {'name': 'segurança', 'color': '#000000', 'description': 'Questões de segurança'},
            {'name': 'backup', 'color': '#c5def5', 'description': 'Backup e recovery'},
            {'name': 'performance', 'color': '#ff6b00', 'description': 'Performance e otimização'},
            {'name': 'github-sync', 'color': '#24292f', 'description': 'Sincronizado do GitHub'},
        ]
        
        created_count = 0
        
        for label_data in infra_labels:
            try:
                self.project.labels.create(label_data)
                created_count += 1
                self.log(f"Label criada: {label_data['name']}")
            except Exception as e:
                # Label já existe ou erro menor
                if "already exists" in str(e).lower():
                    pass
                else:
                    self.log(f"⚠️ Erro ao criar label {label_data['name']}: {str(e)}", "WARN")
        
        self.log(f"✅ Labels de infraestrutura configuradas: {created_count} novas criadas")

    def get_github_issues(self) -> List[Dict]:
        """Busca issues específicas de infraestrutura do GitHub"""
        self.log("📋 Buscando issues de infraestrutura do GitHub...")
        
        try:
            url = f"https://api.github.com/repos/{self.repo_name}/issues"
            params = {
                'state': 'all',
                'per_page': 100,
                'labels': 'infrastructure,devops,deployment,monitoring'  # Issues relevantes para infra
            }
            
            issues = []
            page = 1
            
            while True:
                params['page'] = page
                response = requests.get(url, headers=self.github_headers, params=params)
                
                if response.status_code != 200:
                    self.log(f"❌ Erro ao buscar issues: {response.status_code}", "ERROR")
                    break
                
                page_issues = response.json()
                if not page_issues:
                    break
                
                # Filtrar apenas issues (não PRs)
                for issue in page_issues:
                    if 'pull_request' not in issue:
                        issues.append(issue)
                
                page += 1
                if len(page_issues) < 100:
                    break
            
            self.log(f"✅ Encontradas {len(issues)} issues de infraestrutura no GitHub")
            return issues
            
        except Exception as e:
            self.log(f"❌ Erro ao buscar issues GitHub: {str(e)}", "ERROR")
            return []

    def create_gitlab_issue(self, github_issue: Dict) -> Optional[object]:
        """Cria issue de infraestrutura no GitLab baseada na issue do GitHub"""
        try:
            # Título com prefixo de infraestrutura
            title = f"[INFRA] {github_issue['title']}"
            
            # Descrição com metadados específicos de infraestrutura
            description = f"""## 🏗️ Issue de Infraestrutura Sincronizada do GitHub

{github_issue['body'] or 'Sem descrição'}

---
## 📋 Metadados de Sincronização
- 🔗 **Issue original**: {github_issue['html_url']}
- 👤 **Autor**: @{github_issue['user']['login']} 
- 📅 **Criado**: {github_issue['created_at']}
- 🔢 **ID GitHub**: #{github_issue['number']}
- 🏗️ **Categoria**: Infraestrutura

*Sincronizado automaticamente do repositório de infraestrutura GitHub*
"""
            
            # Processar labels
            labels = []
            for label in github_issue.get('labels', []):
                # Mapear labels de GitHub para GitLab
                label_mapping = {
                    'infrastructure': 'terraform',
                    'devops': 'ci-cd',
                    'deployment': 'ansible',
                    'monitoring': 'monitoramento',
                    'security': 'segurança',
                    'performance': 'performance'
                }
                mapped_label = label_mapping.get(label['name'], label['name'])
                labels.append(mapped_label)
            
            # Adicionar labels específicas de infraestrutura
            labels.extend(['github-sync', 'IMPORTANTE'])
            
            # Determinar estado
            state_event = 'close' if github_issue['state'] == 'closed' else None
            
            # Criar issue no GitLab
            issue_data = {
                'title': title,
                'description': description,
                'labels': ','.join(labels) if labels else None,
            }
            
            if state_event:
                issue_data['state_event'] = state_event
            
            gitlab_issue = self.project.issues.create(issue_data)
            
            self.log(f"✅ Issue de infra criada: #{gitlab_issue.iid} - {title[:50]}...")
            return gitlab_issue
            
        except Exception as e:
            self.log(f"❌ Erro ao criar issue GitLab: {str(e)}", "ERROR")
            return None

    def sync_infrastructure_issues(self):
        """Sincroniza issues específicas de infraestrutura"""
        self.log("🔄 Iniciando sincronização de issues de infraestrutura...")
        
        github_issues = self.get_github_issues()
        
        try:
            gitlab_issues = self.project.issues.list(all=True)
        except Exception as e:
            self.log(f"❌ Erro ao buscar issues GitLab: {str(e)}", "ERROR")
            return
        
        # Criar índice de issues GitLab por título
        gitlab_titles = set()
        for issue in gitlab_issues:
            # Remover prefixo [INFRA] para comparação
            clean_title = issue.title.replace('[INFRA] ', '')
            gitlab_titles.add(clean_title)
        
        created_count = 0
        skipped_count = 0
        
        for github_issue in github_issues:
            original_title = github_issue['title']
            
            # Verificar se já existe
            if original_title in gitlab_titles:
                skipped_count += 1
                continue
            
            # Criar nova issue
            if self.create_gitlab_issue(github_issue):
                created_count += 1
        
        self.log(f"✅ Sincronização de issues concluída: {created_count} criadas, {skipped_count} ignoradas")

    def generate_infrastructure_report(self):
        """Gera relatório específico de infraestrutura"""
        self.log("📊 Gerando relatório de infraestrutura...")
        
        try:
            # Buscar dados
            github_issues = self.get_github_issues()
            gitlab_issues = self.project.issues.list(all=True)
            
            # Estatísticas específicas de infraestrutura
            infra_github_issues = [i for i in github_issues if any(
                label['name'].lower() in ['infrastructure', 'devops', 'deployment', 'monitoring'] 
                for label in i.get('labels', [])
            )]
            
            infra_gitlab_issues = [i for i in gitlab_issues if '[INFRA]' in i.title]
            
            # Gerar relatório
            report = f"""# 📊 Relatório de Sincronização - Infraestrutura Pro-Mata AGES

**Data/Hora**: {datetime.now(timezone.utc).strftime('%d/%m/%Y às %H:%M:%S UTC')}
**Repositório**: {self.repo_name}
**GitLab Project**: {self.gitlab_url}/pro-mata/infra

## 📈 Estatísticas de Infraestrutura

### Issues de Infraestrutura
- **GitHub**: {len(infra_github_issues)} issues de infraestrutura
- **GitLab**: {len(infra_gitlab_issues)} issues sincronizadas
- **Status**: {'✅ Sincronizado' if len(infra_gitlab_issues) >= len(infra_github_issues) else '⚠️ Pendente'}

### Distribuição por Categoria
- **Terraform**: {len([i for i in github_issues if any('terraform' in l['name'].lower() for l in i.get('labels', []))])}
- **Ansible**: {len([i for i in github_issues if any('ansible' in l['name'].lower() for l in i.get('labels', []))])}
- **CI/CD**: {len([i for i in github_issues if any('ci' in l['name'].lower() or 'cd' in l['name'].lower() for l in i.get('labels', []))])}
- **Monitoramento**: {len([i for i in github_issues if any('monitoring' in l['name'].lower() for l in i.get('labels', []))])}

## 🔗 Links Úteis de Infraestrutura
- [📱 Repositório GitHub](https://github.com/{self.repo_name})
- [🦊 Projeto GitLab]({self.gitlab_url}/pro-mata/infra)
- [📋 Board de Infraestrutura]({self.gitlab_url}/pro-mata/infra/-/boards)
- [🚀 Pipelines]({self.gitlab_url}/pro-mata/infra/-/pipelines)

## 🏗️ Componentes de Infraestrutura
- **Ambientes**: Dev, Staging, Produção
- **Cloud Providers**: Azure (Dev/Staging), AWS (Produção)
- **Orquestração**: Docker Swarm, ECS
- **IaC**: Terraform 1.8.0, Ansible 8.5.0
- **CI/CD**: GitHub Actions, GitLab CI

---
*Última sincronização de infraestrutura: {datetime.now(timezone.utc).isoformat()}*
*Sistema de Sincronização Automática Pro-Mata AGES - Infraestrutura*
"""
            
            # Salvar relatório
            with open('infrastructure-sync-report.md', 'w', encoding='utf-8') as f:
                f.write(report)
            
            print(report)
            self.log("✅ Relatório de infraestrutura gerado")
            
        except Exception as e:
            self.log(f"❌ Erro ao gerar relatório: {str(e)}", "ERROR")

    def run_infrastructure_sync(self):
        """Executa sincronização completa de infraestrutura"""
        self.log("🚀 Iniciando sincronização completa de infraestrutura GitHub → GitLab AGES")
        
        try:
            # 1. Configurar labels específicas de infraestrutura
            self.setup_gitlab_labels()
            
            # 2. Espelhar repositório de infraestrutura
            self.mirror_repository()
            
            # 3. Sincronizar issues de infraestrutura
            self.sync_infrastructure_issues()
            
            # 4. Gerar relatório de infraestrutura
            self.generate_infrastructure_report()
            
            self.log("🎉 Sincronização de infraestrutura finalizada com sucesso!", "SUCCESS")
            
        except Exception as e:
            self.log(f"❌ Erro na sincronização de infraestrutura: {str(e)}", "ERROR")
            raise

def main():
    """Função principal"""
    try:
        syncer = ProMataInfrastructureSyncer()
        syncer.run_infrastructure_sync()
        
    except Exception as e:
        print(f"❌ ERRO CRÍTICO na sincronização de infraestrutura: {str(e)}")
        sys.exit(1)

if __name__ == "__main__":
    main()
