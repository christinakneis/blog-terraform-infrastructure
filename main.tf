# -------------------------------------
# Use the AWS provider in the selected region (deined in variables.tf)
# -------------------------------------
provider "aws" {
  region = var.aws_region
}

# -------------------------------------
# Security Group for EC2 Instance
# -------------------------------------
resource "aws_security_group" "web_sg" {
  name_prefix = "web-sg"
  description = "Allow necessary inbound/outbound traffic for Flask app"

  # Inbound rule: allow SSH (optional – for manual login/debugging)
  ingress {
    description      = "Allow SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]  # You can lock this down later
  }

  # Inbound rule: allow traffic from ALB to Flask on port 5000
  ingress {
    description      = "Allow ALB to EC2 on Flask port"
    from_port        = var.web_app_port     # 5000
    to_port          = var.web_app_port
    protocol         = "tcp"
    security_groups  = [aws_security_group.alb_sg.id]  # Only accept traffic from the ALB SG
  }

  # Outbound: allow all (for EC2 to download packages, etc.)
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1" # -1 = all protocols
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

# -------------------------------------
# Security Group for the Load Balancer
# -------------------------------------
resource "aws_security_group" "alb_sg" {
  name_prefix = "alb-sg"
  description = "Allow inbound HTTP/HTTPS to the ALB"

  # Inbound: Allow web traffic from the public internet
  ingress {
    description      = "Allow HTTP (for redirect to HTTPS)"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "Allow HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  # Outbound: allow all (needed for ALB health checks, etc.)
  egress {
    description      = "Allow all outbound traffic"
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
  }
}

# -------------------------------------
# Launch EC2 Instance running Flask
# -------------------------------------
resource "aws_instance" "web" {
  ami           = var.ami_id                     # Ubuntu AMI (set in variables.tf)
  instance_type = var.instance_type              # t2.micro or similar
  subnet_id     = element(var.subnet_ids, 0)     # Use first subnet in list
  user_data     = templatefile("${path.module}/user_data.sh", {
    bucket_name = aws_s3_bucket.backup_bucket.bucket
  })  # Bootstrap shell script with dynamic bucket name
  vpc_security_group_ids = [aws_security_group.web_sg.id]  # Attach EC2 security group
  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name  # Allow S3 access

  tags = {
    Name = "ChristinaKneisWebsite"
  }
}

# -------------------------------------
# Application Load Balancer (ALB)
# -------------------------------------
resource "aws_lb" "web_alb" {
  name               = "web-alb"
  internal           = false                          # Public-facing
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id] # Allow inbound web traffic
  subnets            = var.subnet_ids                 # Public subnets
}

# -------------------------------------
# Target Group for EC2 (on port 5000)
# -------------------------------------
resource "aws_lb_target_group" "web_tg" {
  name        = "web-tg"
  port        = var.web_app_port                     # 5000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "instance"                           # Attach EC2 directly

  # Health check: verifies the Flask app is running
  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    port                = var.web_app_port
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# -------------------------------------
# HTTPS Listener (port 443)
# -------------------------------------
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.acm_cert_arn  # From validated ACM certificate

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web_tg.arn
  }
}

# -------------------------------------
# HTTP Listener that redirects to HTTPS
# -------------------------------------
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# -------------------------------------
# Attach EC2 instance to Target Group
# -------------------------------------
resource "aws_lb_target_group_attachment" "web_attach" {
  target_group_arn = aws_lb_target_group.web_tg.arn
  target_id        = aws_instance.web.id
  port             = var.web_app_port  # 5000
}

# -------------------------------------
# S3 Bucket for Database Backups
# -------------------------------------
resource "aws_s3_bucket" "backup_bucket" {
  bucket = "${var.backup_bucket_name}-${random_id.bucket_suffix.hex}"
  
  tags = {
    Name        = "Blog Database Backups"
    Environment = "Production"
    Purpose     = "Database backup storage"
  }
}

# Random suffix to ensure unique bucket names
resource "random_id" "bucket_suffix" {
  byte_length = 4
}

# S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "backup_versioning" {
  bucket = aws_s3_bucket.backup_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# S3 Bucket Lifecycle Policy (keep backups for 90 days)
resource "aws_s3_bucket_lifecycle_configuration" "backup_lifecycle" {
  bucket = aws_s3_bucket.backup_bucket.id

  rule {
    id     = "backup_retention"
    status = "Enabled"

    filter {
      prefix = "blog_backups/"
    }

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# S3 Bucket Public Access Block (ensure private)
resource "aws_s3_bucket_public_access_block" "backup_private" {
  bucket = aws_s3_bucket.backup_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -------------------------------------
# IAM Role for EC2 to access S3
# -------------------------------------
resource "aws_iam_role" "ec2_s3_access" {
  name = "EC2S3BackupAccess"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name = "EC2 S3 Backup Access"
  }
}

# IAM Policy for S3 backup access
resource "aws_iam_policy" "s3_backup_policy" {
  name        = "S3BackupAccess"
  description = "Allow EC2 to backup database to S3"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:DeleteObject"
        ]
        Resource = [
          aws_s3_bucket.backup_bucket.arn,
          "${aws_s3_bucket.backup_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attach policy to role
resource "aws_iam_role_policy_attachment" "ec2_s3_backup" {
  role       = aws_iam_role.ec2_s3_access.name
  policy_arn = aws_iam_policy.s3_backup_policy.arn
}

# Create instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "EC2S3BackupProfile"
  role = aws_iam_role.ec2_s3_access.name
}
