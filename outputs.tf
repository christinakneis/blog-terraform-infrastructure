# -------------------------------------
# Outputs for the Terraform configuration
# blog-terraform-infrastructure/outputs.tf
# -------------------------------------
output "alb_dns_name" {
  value = aws_lb.web_alb.dns_name
}
