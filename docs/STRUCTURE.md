# infrastructure

This repo stores infrastructure specific artifacts for the MATA project, including Terraform configurations, Ansible playbooks, Dockerfiles, and CI/CD scripts.

## Project Structure

```plaintext
infrastructure/
├── README.md
├── .env.example
├── .gitignore
├── deploy.sh
├── destroy.sh
├── save-terraform-state.sh
├── terraform/
│   ├── modules/
│   │   └── common/
│   │       ├── security-rules/
│   │       ├── ssh-keys/
│   │       ├── inventory/
│   │       └── service-config/
│   ├── aws/
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── network.tf
│   │   ├── instance.tf
│   │   └── inventory.tf
│   └── azure/
│       ├── main.tf
│       ├── providers.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── resource_group.tf
│       ├── network.tf
│       ├── vm.tf
│       └── inventory.tf
│
├── deployment/
│   ├── ansible/
│   │   ├── playbooks/
│   │   │   ├── ansible.cfg
│   │   │   ├── swarm_setup.yml
│   │   │   └── stack.env.j2
│   │   └── roles/
│   │       ├── networking/
│   │       │   └── coredns/
│   │       └── database/
│   │           ├── postgresql/
│   │           ├── pgbouncer/
│   │           └── pgadmin/
│   └── swarm/
│       └── stack.yml.j2
│
├── docker/
│   ├── backend/
│   │   ├── Dockerfile.dev
│   │   ├── Dockerfile.prod
│   │   └── docker-compose.backend.yml
│   ├── frontend/
│   │   ├── Dockerfile.dev
│   │   ├── Dockerfile.prod
│   │   └── docker-compose.frontend.yml
│   └── database/
│       ├── postgresql/
│       ├── pgbouncer/
│       └── pgadmin/
│
├── ci-cd/
│   ├── github-actions/
│   │   ├── build-backend.yml
│   │   ├── build-frontend.yml
│   │   ├── deploy-dev.yml
│   │   ├── deploy-prod.yml
│   │   └── infrastructure-update.yml
│   └── scripts/
│       ├── build-and-push.sh
│       ├── deploy-to-environment.sh
│       └── health-check.sh
│
├── environments/
│   ├── dev/
│   │   ├── .env.dev
│   │   └── docker-compose.dev.yml
│   ├── prod/
│   │   ├── .env.prod
│   │   └── docker-compose.prod.yml
│   └── local/
│       ├── .env.local
│       └── docker-compose.local.yml
│
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   └── logs/
│
└── docs/
    ├── SETUP.md
    ├── DEPLOYMENT.md
    ├── CI-CD.md
    ├── TROUBLESHOOTING.md
    └── ARCHITECTURE.md
```
