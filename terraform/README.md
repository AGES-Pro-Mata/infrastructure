# AWS Production Infrastructure - Terraform Documentation

## 📋 Overview

This directory contains Terraform configurations for AWS production infrastructure. **These files are maintained as documentation and reference only**, as production deployment will use **static IP addresses provided by a third party**.

## 🏗️ Architecture Documentation

The Terraform files document the intended AWS infrastructure architecture:

### Core Components

- **Compute**: EC2 instances for application hosting
- **Database**: RDS PostgreSQL with Multi-AZ for high availability  
- **Networking**: VPC, subnets, security groups, load balancers
- **Storage**: S3 buckets for backups and static assets
- **DNS**: Route53 for domain management
- **Monitoring**: CloudWatch for logging and metrics

### Database Configuration

Production uses the new modular database approach:
- **Base Image**: `norohim/pro-mata-database:latest`
- **Infrastructure Image**: `norohim/pro-mata-database-infrastructure:latest`
- **Migration**: Handled by base image with Prisma support

## 🚀 Deployment Strategy

### Current Approach (Static IPs)
1. **Third Party Provision**: Static IP addresses provided externally
2. **Manual Deployment**: Use Ansible with `envs/prod/` configuration
3. **Database**: Deploy using infrastructure-extended Docker images
4. **Monitoring**: Include analytics stack (Umami, Metabase) if needed

### Future Flexibility
- **Terraform Reference**: Use these files as architecture blueprints
- **Hybrid Approach**: Can adapt to use Terraform when infrastructure requirements change
- **Dev Environment**: Use `envs/dev/` for AWS testing with dev configuration

## 📂 File Structure

```
terraform/
├── main.tf              # Main infrastructure definition
├── variables.tf         # Input variables
├── outputs.tf          # Output values
├── providers.tf        # AWS provider configuration
└── modules/            # Reusable modules
    ├── compute/        # EC2, Auto Scaling
    ├── database/       # RDS configuration
    ├── networking/     # VPC, subnets, security
    └── shared/         # DNS, monitoring, shared resources
```

## ⚠️ Important Notes

1. **Not for Active Deployment**: These files are documentation only
2. **Static IP Integration**: Production uses pre-allocated static IPs
3. **Cost Optimization**: Avoids Terraform state management overhead
4. **Ansible Primary**: Use Ansible playbooks in `ansible/` directory for deployment
5. **Reference Architecture**: Maintain these files for future infrastructure decisions

## 🔧 Usage

To reference the architecture:
```bash
# View planned infrastructure (DO NOT APPLY)
terraform init
terraform plan

# Use for documentation and planning only
```

For actual deployment, use:
```bash
# Deploy via Ansible
make deploy-prod
# or
ansible-playbook -i envs/prod/ ansible/playbooks/deploy.yml
```