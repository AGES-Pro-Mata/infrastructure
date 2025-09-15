# ============================================================================
# modules/storage/outputs.tf
# ============================================================================
output "s3_bucket_name" {
  description = "Name of the application files S3 bucket"
  value       = aws_s3_bucket.application_files.bucket
}

output "s3_bucket_arn" {
  description = "ARN of the application files S3 bucket"
  value       = aws_s3_bucket.application_files.arn
}

output "s3_bucket_domain_name" {
  description = "Domain name of the S3 bucket"
  value       = aws_s3_bucket.application_files.bucket_domain_name
}