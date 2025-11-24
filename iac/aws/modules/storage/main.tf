# ============================================================================
# modules/storage/main.tf - S3 for Static Assets Only
# ============================================================================

# Random ID for globally unique bucket name
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# S3 BUCKET - STATIC ASSETS (PDFs, Images, Frontend Files)
# Purpose: Store user-uploaded files and frontend assets
# NOT for Terraform state (stored in Azure)
# ============================================================================

resource "aws_s3_bucket" "static_assets" {
  bucket = "${local.name_prefix}-static-assets-${random_id.bucket_suffix.hex}"

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-static-assets"
    Purpose = "frontend-pdfs-images"
  })
}

resource "aws_s3_bucket_versioning" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST", "PUT", "DELETE", "HEAD"]
    allowed_origins = ["https://*.promata.com.br", "https://promata.com.br"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# ============================================================================
# S3 BUCKET LIFECYCLE POLICY - Auto-delete old versions after 90 days
# ============================================================================

resource "aws_s3_bucket_lifecycle_configuration" "static_assets" {
  bucket = aws_s3_bucket.static_assets.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 90
    }
  }

  rule {
    id     = "abort-incomplete-multipart-uploads"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}