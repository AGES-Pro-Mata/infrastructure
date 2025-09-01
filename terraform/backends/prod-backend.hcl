bucket         = "promata-prod-terraform-state"
key            = "prod/infrastructure.tfstate"
region         = "us-east-2"
dynamodb_table = "promata-terraform-locks"
encrypt        = true
