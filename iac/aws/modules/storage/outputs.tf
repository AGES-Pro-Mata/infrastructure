# ============================================================================
# modules/storage/outputs.tf
# ============================================================================
output "s3_bucket_name" {
  description = "Name of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the static assets S3 bucket"
  value       = aws_s3_bucket.static_assets.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket_domain_name
}

output "s3_bucket_regional_domain_name" {
  description = "Regional domain name of the S3 bucket"
  value       = aws_s3_bucket.static_assets.bucket_regional_domain_name
}

output "s3_website_endpoint" {
  description = "S3 static website endpoint URL"
  value       = aws_s3_bucket_website_configuration.static_assets.website_endpoint
}

output "s3_website_domain" {
  description = "S3 static website domain (for nginx proxy)"
  value       = "${aws_s3_bucket.static_assets.bucket}.s3-website-${var.aws_region}.amazonaws.com"
}