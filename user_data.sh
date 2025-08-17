#!/bin/bash

# -------------------------------------
# Loge user_data.tpl actions to a file for debugging
# -------------------------------------
exec > >(tee /var/log/user_data.log|logger -t user-data -s 2>/dev/console) 2>&1
set -e

# -------------------------------------
# Install packages
# -------------------------------------
sudo apt update -y
sudo apt install -y python3-pip python3-venv git

# -------------------------------------
# Clone the Flask webapp repo
# -------------------------------------
cd /home/ubuntu
git clone https://github.com/christinakneis/blog-flask-webapp.git
cd blog-flask-webapp

# -------------------------------------
# Create virtual environment & install requirements
# -------------------------------------
python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

# -------------------------------------
# Run the app with Gunicorn
# -------------------------------------
APP_PORT=5000
nohup gunicorn -w 1 -b 0.0.0.0:$APP_PORT run:app & # Run in the background (nohup allows it to continue running after user logs out)

# -------------------------------------
# Install AWS CLI for S3 backups
# -------------------------------------
sudo apt install -y awscli

# -------------------------------------
# Create backup script
# -------------------------------------
cat > /home/ubuntu/backup_db.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/ubuntu/backups"
mkdir -p $BACKUP_DIR

# Create backup
cp /home/ubuntu/blog-flask-webapp/instance/blog.db $BACKUP_DIR/blog_$DATE.db

# Upload to S3 (bucket name will be available from Terraform output)
BUCKET_NAME="REPLACE_WITH_ACTUAL_BUCKET_NAME"
aws s3 cp $BACKUP_DIR/blog_$DATE.db s3://$BUCKET_NAME/blog_backups/blog_$DATE.db

# Keep only last 7 local backups
ls -t $BACKUP_DIR/blog_*.db | tail -n +8 | xargs rm -f

# Log the backup
echo "$(date): Database backed up to S3 as blog_$DATE.db" >> /var/log/backup.log
EOF

# Make backup script executable
chmod +x /home/ubuntu/backup_db.sh

# -------------------------------------
# Set up daily backup at 2 AM
# -------------------------------------
(crontab -l 2>/dev/null; echo "0 2 * * * /home/ubuntu/backup_db.sh") | crontab -

# -------------------------------------
# Create initial backup
# -------------------------------------
/home/ubuntu/backup_db.sh
