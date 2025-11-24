# Outputs for AWS S3 Frontend Module

output "bucket_id" {
  description = "ID do bucket S3"
  value       = aws_s3_bucket.frontend.id
}

output "bucket_arn" {
  description = "ARN do bucket S3"
  value       = aws_s3_bucket.frontend.arn
}

output "bucket_name" {
  description = "Nome do bucket S3"
  value       = aws_s3_bucket.frontend.bucket
}

output "website_endpoint" {
  description = "Endpoint do website S3"
  value       = aws_s3_bucket_website_configuration.frontend.website_endpoint
}

output "website_domain" {
  description = "Domínio do website S3"
  value       = aws_s3_bucket_website_configuration.frontend.website_domain
}

output "bucket_regional_domain_name" {
  description = "Nome do domínio regional do bucket"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}
