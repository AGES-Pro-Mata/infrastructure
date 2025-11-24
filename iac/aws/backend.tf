# Terraform Backend Configuration
# S3 backend em sa-east-1 (São Paulo)
# Execute scripts/terraform/setup-backend.sh primeiro para criar bucket e DynamoDB table
# Note: Backend will be disabled for testing. Remove or comment this block to use local state.

# terraform {
#   backend "s3" {
#     bucket         = "promata-terraform-state"
#     key            = "aws/terraform.tfstate"
#     region         = "sa-east-1"
#     encrypt        = true
#     dynamodb_table = "promata-terraform-locks"
#   }
# }
