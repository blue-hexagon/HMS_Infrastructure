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
pip install gunicorn django djangorestframework django-cors-headers
echo "Collecting static files..."
python manage.py collectstatic --noinput
sudo apt install libpq-dev python3-dev
pip install psycopg2
echo "[3/5]: Django HMS Configured."

######################################################################################
#---------------------------------- Nginx Config ------------------------------------#
######################################################################################

echo "Configuring backend node (NGINX + Gunicorn)..."

sudo tee /etc/nginx/sites-available/hms > /dev/null <<EOF
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:8000;
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
EOF

sudo ln -sf /etc/nginx/sites-available/hms /etc/nginx/sites-enabled/hms
sudo rm /etc/nginx/sites-enabled/default
echo "[4/5]: Nginx Configured."
######################################################################################
#--------------------------------- Gunicorn Config ----------------------------------#
######################################################################################
sudo tee /etc/systemd/system/gunicorn.service > /dev/null <<EOF
[Unit]
Description=gunicorn daemon
After=network.target

[Service]
User=www-data
Group=www-data
WorkingDirectory=$APP_DIR
ExecStart=$VENV_DIR/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 hms.wsgi:application

[Install]
WantedBy=multi-user.target
EOF
echo "[5/5]: Gunicorn daemon Configured."
######################################################################################
#------------------------------ Reload all Services ---------------------------------#
######################################################################################
source $VENV_DIR/bin/activate
python manage.py makemigrations
python manage.py migrate
exit

sudo systemctl daemon-reload
sudo systemctl enable gunicorn
sudo systemctl start gunicorn

echo "Testing and reloading NGINX..."
sudo nginx -t && sudo systemctl reload nginx

echo "[DONE:$ROLE]: Reloaded all services"
