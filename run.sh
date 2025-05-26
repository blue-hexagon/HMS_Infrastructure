set +x
rm -Rf HMS_Infrastructure
sudo apt remove nginx-full -y
sudo apt purge nginx-full -y
sudo rm -Rf /var/www/hms
git clone https://github.com/blue-hexagon/HMS_Infrastructure
chmod a+x -R ./HMS_Infrastructure
cd HMS_Infrastructure
sudo ./init.sh
