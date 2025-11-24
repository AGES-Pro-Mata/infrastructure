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