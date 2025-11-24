# AWS S3 Frontend Module
# Static website hosting para frontend React

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.80"
    }
  }
}

# S3 Bucket
resource "aws_s3_bucket" "frontend" {
  bucket = var.bucket_name

  tags = merge(var.tags, {
    Name        = var.bucket_name
    Environment = var.environment
    Purpose     = "Frontend Static Website"
  })
}

# Website Configuration
resource "aws_s3_bucket_website_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html" # SPA routing - all errors go to index.html
  }
}

# Versioning (optional, useful for rollbacks)
resource "aws_s3_bucket_versioning" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  versioning_configuration {
    status = var.enable_versioning ? "Enabled" : "Disabled"
  }
}

# CORS Configuration
resource "aws_s3_bucket_cors_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = [
      "https://${var.domain_name}",
      "https://www.${var.domain_name}",
      "https://api.${var.domain_name}",
    ]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Public Access Block (disable to allow public website)
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

# Bucket Policy - Public Read Access
resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.frontend.arn}/*"
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.frontend]
}

# Lifecycle Rules (optional - clean old versions)
resource "aws_s3_bucket_lifecycle_configuration" "frontend" {
  count  = var.enable_versioning ? 1 : 0
  bucket = aws_s3_bucket.frontend.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Server-Side Encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
