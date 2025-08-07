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
