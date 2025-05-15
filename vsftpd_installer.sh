#!/bin/bash
######################################################################################
#------------------------------------ Input Data -------------------------------------
######################################################################################
if [ -z "$COMPANY_NAME" ]; then
  export COMPANY_NAME="nhi"
fi
ftp_users=("${COMPANY_NAME}_ro" "${COMPANY_NAME}_rw" "${COMPANY_NAME}_admin")
ftp_passwords=("Kode1234!" "Kode1234!" "Kode1234!")
echo "[1/9]: Config data loaded."

######################################################################################
#------------------------------------ Initialize ------------------------------------
######################################################################################
sudo apt update && sudo apt upgrade -y
sudo apt install nginx vsftpd openssl ufw -y
sudo useradd -m "ftpuser"
systemctl enable --now vsftpd
systemctl enable --now ufw
systemctl enable --now nginx
echo "[2/9]: System initialized."

######################################################################################
#---------------------------------------- UFW ----------------------------------------
######################################################################################
ufw allow 20/tcp
ufw allow 21/tcp
ufw allow 22/tcp
ufw allow 30000:31000/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 900/tcp
ufw --force enable
ufw reload
echo "[3/9]: UFW Configured and activated."

######################################################################################
#---------------------------------Create FTP Users-----------------------------------
######################################################################################
sudo groupadd sharedftp
sudo groupadd sharedftp
mkdir -p /etc/vsftpd/user_config
touch /etc/vsftpd/user_list
for i in "${!ftp_users[@]}"; do
    user="${ftp_users[$i]}"
    pass="${ftp_passwords[$i]}"
    id "${user}" &>/dev/null || sudo useradd -m "$user" -s /usr/sbin/nologin 
    sudo usermod -aG sharedftp "$user"
    echo "$user:$pass" | sudo chpasswd
    grep -q "^${user}$" /etc/vsftpd/user_list || echo "${user}" >> /etc/vsftpd/user_list
done
echo "[4/9]: Users configured."

######################################################################################
#--------------------------------- Configure VSFTPD ----------------------------------
######################################################################################
sudo mkdir -p /srv/ftp/nhi
sudo chown root:sharedftp /srv/ftp/nhi
sudo chmod 777 /srv/ftp/nhi

sudo mkdir -p /srv/ftp/nhi/research_papers
sudo chown root:sharedftp /srv/ftp/nhi/research_papers
sudo chmod 777 /srv/ftp/nhi/research_papers

cat <<EOF | sudo tee /etc/vsftpd.conf > /dev/null
ftpd_banner=Velokmmen til NHIs Sikre FTP Service

xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
log_ftp_protocol=YES

local_enable=YES
local_root=/srv/ftp/nhi
allow_writeable_chroot=YES
write_enable=YES
dirlist_enable=YES
anonymous_enable=NO
user_config_dir=/etc/vsftpd/user_config
chown_upload_mode=0777

chroot_local_user=YES
chroot_list_enable=YES
chroot_list_file=/etc/vsftpd/vsftpd.chroot

chown_uploads=YES
chown_username=ftpuser
file_open_mode=0664
local_umask=002

pasv_min_port=30000
pasv_max_port=31000
local_max_rate=100000000

userlist_file=/etc/vsftpd/user_list
userlist_deny=NO

ssl_enable=YES
#force_local_data_ssl=YES
#force_local_logins_ssl=YES

rsa_cert_file=/etc/vsftpd/vsftpd.pem
rsa_private_key_file=/etc/vsftpd.pem

idle_session_timeout=300
data_connection_timeout=60

listen=YES
listen_ipv6=NO
EOF
echo "${COMPANY_NAME}_admin" > /etc/vsftpd/vsftpd.chroot
echo "[5/9]: VSFTPD Configured."

######################################################################################
#---------------------------- Configure SSL for VSFTPD -------------------------------
######################################################################################
if [ ! -f /etc/vsftpd/vsftpd.pem ]; then
	sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/vsftpd.pem -out /etc/vsftpd/vsftpd.pem
fi
systemctl restart vsftpd
echo "[6/9]: SSL Configured for VSFTPD."

######################################################################################
#------------------Configure logging and logrotation for VSFTPD-----------------------
######################################################################################
touch /var/log/vsftpd.log
chown ftpuser:adm /var/log/vsftpd.log
chmod 640 /var/log/vsftpd.log
sudo tee /etc/logrotate.d/vsftpd > /dev/null <<EOF
/var/log/vsftpd.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
}
EOF
echo "[7/9]: Logrotation Configured for VSFTPD."

######################################################################################
#---------------------------- Configure NGINX FTP Site -------------------------------
######################################################################################
cat <<EOF | sudo tee /etc/nginx/sites-available/archive > /dev/null
server {
    listen 80;
    server_name nhi-archive.local;

    access_log /var/log/nginx/archive_access.log;

    location /nhi/ {
        root /srv/ftp;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        charset utf-8;
        disable_symlinks if_not_owner;
    }

    location ~ /\. {
        deny all;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/archive /etc/nginx/sites-enabled/archive
sudo chown -R root:sharedftp /srv/ftp/nhi
sudo chmod 2775 /srv/ftp/nhi
nginx -t && systemctl reload nginx
echo "[8/9]: NGINX Configured (access from <host>/nhi/)."

######################################################################################
#---------------- Configure Cronjob for sanitizing user uploads ----------------------
######################################################################################
sudo tee /usr/local/bin/fix-ftp-perms.sh > /dev/null <<'EOF'
#!/bin/bash
chown -R ftpuser:sharedftp /srv/ftp/nhi
chmod -R g+rwx /srv/ftp/nhi
find /srv/ftp/nhi -type d -exec chmod 2775 {} \;
EOF
sudo chmod +x /usr/local/bin/fix-ftp-perms.sh
(crontab -l 2>/dev/null; echo "0 1 * * * /usr/local/bin/fix-ftp-perms.sh") | crontab -
echo "[9/9]: Cronjob for FTP user submission file sanitation configured."

######################################################################################
#------------------------------ Reload all Services ----------------------------------
######################################################################################
systemctl restart vsftpd || systemctl reload vsftpd
systemctl restart ufw 
systemctl restart nginx
echo "[DONE]: Reloaded all services"


usermod -aG sharedftp www-data
#