# 🚀 Terraform Deployment for christinakneis.com

This Terraform configuration deploys my personal portfolio site — a Flask web app hosted on an EC2 instance behind an Application Load Balancer (ALB). It uses a `user_data.sh` script to automatically pull the app from GitHub and run it with Gunicorn on startup.

---

## 💡 Architecture Overview

- **Flask App** hosted on **EC2**
- **Gunicorn** used as the WSGI server
- **Application Load Balancer** (ALB) routes HTTP traffic to the EC2 instance
- **Security Group** allows ports `22`, `80`, and `443`
- **Bootstrapped with `user_data.sh`** to auto-deploy app from GitHub

---

## 🔧 Usage

### 1. Clone this repo

```bash
git clone https://github.com/christinakneis/blog-flask-webapp.git
cd infra/
```

### 2. Initialize Terraform

```bash
terraform init
```

### 3. Set required variables

#### Either: 
You'll need to pass in your **VPC ID** and **Subnet IDs** (use your default VPC and public subnets):

```bash
terraform plan \
  -var="vpc_id=vpc-xxxxxxxx" \
  -var='subnet_ids=["subnet-abc12345", "subnet-def67890"]'
```

#### Or: 

Copy the terraform.tfvars.example template:

```bash
cp terraform.tfvars.example terraform.tfvars
```

And replace the VPC and subnet with your values:
```
vpc_id     = "vpc-xxxxxxxxxxxxxxxxx"
subnet_ids = ["subnet-xxxxxxxxxxxxxx", "subnet-yyyyyyyyyyyyyy"]
```

Then you can simply run: 
```bash
terraform plan 
```

### 4. Deploy!

#### Either (if you manually passed in your **VPC ID** and **Subnet IDs** in the previous step)
```bash
terraform apply \
  -var="vpc_id=vpc-xxxxxxxx" \
  -var='subnet_ids=["subnet-abc12345", "subnet-def67890"]'
```

#### Or (if you set up your terraform.tfvars in the previous step)
```bash
terraform apply 
```

### 5. Access the site 🎉

Once Terraform finishes, it will output a DNS name like:

```
alb_dns_name = web-alb-1234567890.us-east-2.elb.amazonaws.com
```

Open that in your browser and your app should be live!

---

## ⚙️ Configuration

You can customize the following variables in `variables.tf`:

| Variable         | Description                          | Default       |
|------------------|--------------------------------------|---------------|
| `aws_region`     | AWS Region                           | `us-east-2`   |
| `ami_id`         | Ubuntu AMI for the region            | See `variables.tf` |
| `instance_type`  | EC2 instance type                    | `t2.micro`    |
| `vpc_id`         | VPC where the infra will live        | *(required)*  |
| `subnet_ids`     | List of subnets for the ALB          | *(required)*  |
| `web_app_port`   | Port the Flask app listens on        | `5000`        |

---

## 📁 File Structure

```
infra/
├── main.tf          # Main infra definition
├── variables.tf     # Input variables
├── outputs.tf       # Outputs (e.g. ALB DNS)
├── user_data.sh     # EC2 bootstrap script
```

---

## 📌 Notes

- The Flask app must expose `run:app` as the Gunicorn entry point.
- Others using this code can replace the GitHub repo in `user_data.sh` if needed.
- Don't forget to associate the Route 53 domain (e.g. `christinakneis.com`)!

---

## 🚚 CI/CD 

This project is designed to support continuous integration and deployment (CI/CD) using GitHub Actions.

Planned workflow:
- Auto-deploy to EC2 when changes are pushed to the `main` branch
- Pull latest code and restart Gunicorn using a lightweight deployment script
- (Optional Future work) Add pre-deployment testing, linting, and version tagging

This will allow me to iterate quickly while keeping my production site stable and secure.

---

## 🧠 Author

Built with ✨ and ☕ by Christina Kneis.