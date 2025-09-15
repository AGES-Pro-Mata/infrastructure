# ============================================================================
# modules/terraform_backend/main.tf
# ============================================================================
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# DYNAMODB TABLE FOR TERRAFORM STATE LOCKING
# ============================================================================
resource "aws_dynamodb_table" "terraform_state_lock" {
  name           = "${var.project_name}-terraform-state-lock"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled = true
  }

  point_in_time_recovery {
    enabled = true
  }

  tags = merge(var.tags, {
    Name        = "${var.project_name}-terraform-state-lock"
    Purpose     = "terraform-state-lock"
    Environment = "shared"
  })
}