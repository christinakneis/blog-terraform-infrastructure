# -------------------------------------
# Outputs for the Terraform configuration
# blog-terraform-infrastructure/outputs.tf
# -------------------------------------
output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}

output "backup_bucket_name" {
  value = aws_s3_bucket.backup_bucket.bucket
  description = "Name of the S3 bucket for database backups"
}

output "backup_bucket_arn" {
  value = aws_s3_bucket.backup_bucket.arn
  description = "ARN of the S3 bucket for database backups"
}
