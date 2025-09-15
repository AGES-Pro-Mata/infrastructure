# ============================================================================
# modules/storage/main.tf
# ============================================================================
locals {
  name_prefix = "${var.project_name}-${var.environment}"
}

# ============================================================================
# S3 BUCKET - APPLICATION FILES (PDFs, EMAILS, ATTACHMENTS)
# ============================================================================
resource "aws_s3_bucket" "application_files" {
  bucket = "${local.name_prefix}-app-files"

  tags = merge(var.tags, {
    Name    = "${local.name_prefix}-application-files"
    Purpose = "application-files"
  })
}

resource "aws_s3_bucket_versioning" "application_files" {
  bucket = aws_s3_bucket.application_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "application_files" {
  bucket = aws_s3_bucket.application_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "application_files" {
  bucket = aws_s3_bucket.application_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_cors_configuration" "application_files" {
  bucket = aws_s3_bucket.application_files.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "POST", "PUT", "DELETE", "HEAD"]
    allowed_origins = ["*"]
    max_age_seconds = 3000
  }
}