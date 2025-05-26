#!/bin/bash
######################################################################################
#----------------------------------- Input Data -------------------------------------#
######################################################################################
APP_REPO="https://github.com/blue-hexagon/django-rest-hms"
APP_DIR="/var/www/hms"
VENV_DIR="$APP_DIR/venv"
DOMAIN="srv-lb01.local"
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

######################################################################################
#---------------------------------- Nginx Config ------------------------------------#
######################################################################################
echo "Setting up Load Balancer NGINX config..."
sudo tee /etc/nginx/sites-available/hms > /dev/null <<EOF

events {}

http {
    upstream web_frontend_pool {
        ip_hash;
        server ${LB_IPS[0]} max_fails=3 fail_timeout=15s;
        server ${LB_IPS[1]} max_fails=3 fail_timeout=15s;
    }

    server {
        listen 80;
        server_name $DOMAIN;

        location / {
            proxy_pass http://web_frontend_pool;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /static/ {
            root $APP_DIR/staticfiles/;
        }

        location /media/ {
            root $APP_DIR/mediafiles/;
        }
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/hms /etc/nginx/sites-enabled/hms

echo "Testing and reloading NGINX..."
sudo nginx -t && sudo systemctl reload nginx

echo "[DONE:$ROLE]: Reloaded all services"
