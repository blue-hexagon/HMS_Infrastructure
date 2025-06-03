#!/bin/bash
######################################################################################
#----------------------------------- Input Data -------------------------------------#
######################################################################################
APP_REPO="https://github.com/blue-hexagon/django-rest-hms"
APP_DIR="/var/www/hms"
VENV_DIR="$APP_DIR/venv"
DOMAIN="srv-lb01.nhi.it"
LB_IPS=("192.168.10.21" "192.168.10.22")
echo "[1/5]: Config data loaded."

######################################################################################
#------------------------------------ Initialize ------------------------------------#
######################################################################################
echo "Updating system..."
sudo apt update && sudo apt upgrade -y
sudo apt install -y nginx-full git python3 python3-venv python3-pip
echo "[2/5]: System initialized."

######################################################################################
#----------------------------------- Django HMS -------------------------------------#
######################################################################################
echo "Cloning application..."
sudo rm -rf $APP_DIR
sudo git clone $APP_REPO $APP_DIR
cd $APP_DIR
echo "Creating virtual environment..."
python3 -m venv $VENV_DIR
source $VENV_DIR/bin/activate

echo "Installing dependencies..."
if [ -f requirements.txt ]; then
    pip install -r requirements.txt
fi
pip install gunicorn django djangorestframework psycopg2-binary
echo "Collecting static files..."
python manage.py collectstatic --noinput
echo "[3/5]: Django HMS Configured."

## TODO ##
sudo openssl req -x509 -nodes -days 365 \
  -newkey rsa:2048 \
  -keyout /etc/ssl/private/nginx-selfsigned.key \
  -out /etc/ssl/certs/nginx-selfsigned.crt \
  -subj "/C=DK/ST=Denmark/L=Copenhagen/O=NHI/OU=IT/CN=hms.nhi.it"

sudo chmod 600 /etc/ssl/private/nginx-selfsigned.key
sudo chown root:root /etc/ssl/private/nginx-selfsigned.key
sudo chgrp www-data -R /var/www/hms/staticfiles
sudo chown www-data -R /var/www/hms/staticfiles
sudo chmod 766 -R /var/www/hms/staticfiles
######################################################################################
#---------------------------------- Nginx Config ------------------------------------#
######################################################################################
echo "Setting up Load Balancer NGINX config..."
sudo tee /etc/nginx/conf.d/hms_upstream.conf > /dev/null <<EOF
upstream django_hms {
    ip_hash;
    server ${LB_IPS[0]}:8000 max_fails=3 fail_timeout=15s;
    server ${LB_IPS[1]}:8000 max_fails=3 fail_timeout=15s;
}
EOF

sudo tee /etc/nginx/sites-available/hms > /dev/null <<EOF
#log_format upstream_logging '[$time_local] $remote_addr - $remote_user - $server_name to: "$upstream": "$request" upstream_response_time $upstream_response_time msec $msec request_time $request_time';
server {
    # Upgrade HTTP to HTTPS
    listen 80;
    server_name hms.nhi.it 192.168.10.27;

    location / {
        return 301 https://$host$request_uri;
    }
}
server {
    listen 443 ssl;
    server_name hms.nhi.it;

    ssl_certificate     /etc/ssl/certs/nginx-selfsigned.crt;
    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;

    location / {
        proxy_pass http://django_hms;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

    }

    location /static/ {
        alias $APP_DIR/staticfiles/;
    }

    location /media/ {
        alias $APP_DIR/mediafiles/;
    }

    access_log /var/log/nginx/hms.access.log;
    error_log /var/log/nginx/hms.error.log info;
    
}
EOF
sudo ln -sf /etc/nginx/sites-available/hms /etc/nginx/sites-enabled/hms
sudo rm /etc/nginx/sites-enabled/default

echo "Testing and reloading NGINX..."
sudo nginx -t && sudo systemctl reload nginx

echo "[DONE:$ROLE]: Reloaded all services"
