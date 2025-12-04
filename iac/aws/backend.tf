# Terraform Backend Configuration
# S3 backend em sa-east-1 (São Paulo)
# Execute scripts/terraform/setup-backend-aws.sh primeiro para criar bucket e DynamoDB table
#
# IMPORTANTE: Backend habilitado para compartilhamento de state entre equipe/CI

terraform {
  backend "s3" {
    bucket         = "promata-terraform-state"
    key            = "aws/prod/terraform.tfstate"
    region         = "sa-east-1"
    encrypt        = true
    dynamodb_table = "promata-terraform-locks"
  }
}

# ============================================================================
# STATE LOCKING - DynamoDB
# ============================================================================
# O DynamoDB table "promata-terraform-locks" previne que múltiplos usuários
# ou CI/CD pipelines executem terraform apply simultaneamente.
#
# Se precisar forçar unlock (use com cuidado!):
#   terraform force-unlock <LOCK_ID>
# ============================================================================
