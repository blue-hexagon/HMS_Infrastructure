#!/bin/bash
# wget -qO- https://raw.githubusercontent.com/blue-hexagon/HMS_Infrastructure/refs/heads/master/wget.sh | sudo bash -s -- ARG
# lb|db|ftpes|sethostname|hms

apt install git
set +x
rm -Rf HMS_Infrastructure
sudo apt remove nginx-full -y
sudo apt purge nginx-full -y
sudo rm -Rf /var/www/hms
git clone https://github.com/blue-hexagon/HMS_Infrastructure
chmod a+x -R ./HMS_Infrastructure
cd HMS_Infrastructure
chmod a+x init.sh
sudo ./init.sh