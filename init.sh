#!/bin/bash

sudo chmod a+rwx ./ftpes/installer.sh
sudo chmod a+rwx ./hms_and_lb/hms_installer.sh
sudo chmod a+rwx ./hms_and_lb/lb_installer.sh
sudo chmod a+rwx ./hms_and_lb/db_installer.sh
sudo chmod a+rwx ./hms_and_lb/db_setup.sql

if [[ -z "$1" ]]; then
    echo "Usage: $0 {lb|hms|db|ftpes}"
    exit 1
fi
export COMPANY_NAME="nhi"
export COMPANY_TLD="it"
export COMPANY_DOMAIN="${COMPANY_NAME}.${COMPANY_TLD}"
export DEPARTMENTS_STR="labs,research,ledelse,hr,it,sikkerhed"
export HOST_IP=$(ip -4 route get 1.1.1.1 | awk '{print $7}')

if [[ ! -f /tmp/hostname_set.lock ]]; then
    sudo hostnamectl set-hostname "${HOST_IP//./-}.${COMPANY_DOMAIN}"
    touch /tmp/hostname_set.lock
fi

if [[ "$1" == "lb" ]]; then
    sudo -E ~/HMS_Infrastructure/hms_and_lb/lb_installer.sh

elif [[ "$1" == "hms" ]]; then
    sudo -E ~/HMS_Infrastructure/hms_and_lb/hms_installer.sh

elif [[ "$1" == "db" ]]; then
    sudo -E ~/HMS_Infrastructure/hms_and_lb/db_installer.sh
    sudo chmod a+r ~/HMS_Infrastructure/hms_and_lb/db_setup.sql
    sudo cat /root/HMS_Infrastructure/hms_and_lb/db_setup.sql | sudo -u postgres psql

elif [[ "$1" == "ftpes" ]]; then
    sudo -E ~/HMS_Infrastructure/ftpes/installer.sh
    sudo -E cp ~/HMS_Infrastructure/ftpes/index.html /srv/ftp/nhi/index.html
    sudo -E cp ~/HMS_Infrastructure/ftpes/autoindex.css /srv/ftp/nhi/autoindex.css
    sudo -E cp ~/HMS_Infrastructure/ftpes/banner.html /srv/ftp/nhi/banner.html  

else
    echo "Invalid argument: $1"
    
fi
