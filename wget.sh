#!/bin/bash
cd $HOME
echo "@ ${HOME}"
apt install git
set +x
rm -Rf HMS_Infrastructure
sudo apt remove nginx-full -y
sudo apt purge nginx-full -y
sudo rm -Rf /var/www/hms
git clone https://github.com/blue-hexagon/HMS_Infrastructure
chmod a+x -R ./HMS_Infrastructure
cd ./HMS_Infrastructure
chmod a+x ./init.sh
echo "Initializing with: ${1}"
sudo ./init.sh $1