variable "aws_region" {
  default = "us-east-2"
}

variable "ami_id" {
  description = "Ubuntu AMI for us-east-2"
  default     = "ami-08a98e6d1b5aa6099" # Can find the latest Ubuntu AMI here:  https://cloud-images.ubuntu.com/locator/ec2/ (Region: us-east-2; Version: 22.04 LTS; Arch: amd64; Instance Type: hvm:ebs-ssd)
}

variable "instance_type" {
  default = "t2.micro"
}

variable "vpc_id" {
  description = "Default VPC ID" # see terraform.tfvars
}

variable "subnet_ids" {
  type = list(string)
  description = "List of subnet IDs" # see terraform.tfvars
}

# -------------------------------------
# Web app variables
# -------------------------------------
variable "web_app_port" {
  default     = 5000
  description = "The internal port the Flask app listens on"
}

# ACM certificate ARN for HTTPS
variable "acm_cert_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
}

