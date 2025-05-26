#!/bin/bash

# apt install git
# git clone https://github.com/blue-hexagon/HMS_Infrastructure
# cd HMS_Infrastructure
# chmod a+x init.sh

sudo chmod ugo+rwx ./ftpes/installer.sh
sudo chmod ugo+rwx ./hms_and_lb/hms_installer.sh
sudo chmod ugo+rwx ./hms_and_lb/lb_installer.sh

if [[ -z "$1" ]]; then
    echo "Usage: $0 {lb|hms|ftpes|sethostname}"
    exit 1
fi
export COMPANY_NAME="nhi"
export COMPANY_TLD="it"
export COMPANY_DOMAIN="${COMPANY_NAME}.${COMPANY_TLD}.local"
export DEPARTMENTS_STR="labs,research,ledelse,hr,it,sikkerhed"
export HOST_IP=$(ip -4 route get 1.1.1.1 | awk '{print $7}')

if [[ "$1" == "lb" ]]; then
    sudo ./hms_and_lb/lb_installer.sh
elif [[ "$1" == "hms" ]]; then
    sudo ./hms_and_lb/hms_installer.sh
elif [[ "$1" == "ftpes" ]]; then
    sudo ./ftpes/installer.sh
elif [[ "$1" == "sethostname" ]]; then
    sudo hostnamectl set-hostname "${HOST_IP//./-}.${COMPANY_DOMAIN}"
else
    echo "Invalid argument: $1"
fi
