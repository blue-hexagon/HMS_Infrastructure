#!/bin/bash
######################################################################################
#------------------------------------ Input Data ------------------------------------#
######################################################################################
if [ -z "$COMPANY_NAME" ]; then
    COMPANY_NAME="nhi"
fi
if [ -z "$COMPANY_DOMAIN" ]; then
    COMPANY_DOMAIN="nhi.it"
fi
if [ -z "$HOST_IP" ]; then
    HOST_IP="192.168.10.37"
fi
if [[ ${#DEPARTMENTS[@]} -eq 0 ]]; then
    IFS=',' read -ra DEPARTMENTS <<< "$DEPARTMENTS_STR"
    for dep in "${DEPARTMENTS[@]}"; do
        echo "Creating department: $dep"
    done
fi

ftp_users=()
ftp_passwords=()

for dept in "${DEPARTMENTS[@]}"; do
  ftp_users+=("${COMPANY_NAME}_${dept}_ro")
  ftp_users+=("${COMPANY_NAME}_${dept}_rw")
  ftp_passwords+=("Kode1234!" "Kode1234!")
done
ftp_users+=("${COMPANY_NAME}_admin")
ftp_passwords+=("Admin1234!")
ftp_users+=("${COMPANY_NAME}_ansat")
ftp_passwords+=("Kode1234!")
echo "[1/9]: Config data loaded."

######################################################################################
#------------------------------------ Initialize -----------------------------------#
######################################################################################
sudo apt update && sudo apt upgrade -y
sudo apt install nginx-full vsftpd openssl ufw apache2-utils -y
set -e
sudo useradd -m "ftpuser"
systemctl enable --now vsftpd
systemctl enable --now ufw
systemctl enable --now nginx
echo "[2/9]: System initialized."

######################################################################################
#---------------------------------------- UFW ---------------------------------------#
######################################################################################
ufw allow 20/tcp
ufw allow 21/tcp
ufw allow 22/tcp
ufw allow 30000:31000/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw reload
echo "[3/9]: UFW Configured and activated."

######################################################################################
#---------------------------------Create FTP Users----------------------------------#
######################################################################################
sudo groupadd sharedftp
usermod -aG sharedftp www-data
mkdir -p /etc/vsftpd/user_config
touch /etc/vsftpd/user_list
for i in "${!ftp_users[@]}"; do
    user="${ftp_users[$i]}"
    pass="${ftp_passwords[$i]}"
    id "${user}" &>/dev/null || sudo useradd -m "$user" -s /bin/bash 
    sudo usermod -aG sharedftp "$user"
    echo "$user:$pass" | sudo chpasswd
    if [[ "$user" == *ro ]] || [[ "$user" == *ansat ]] || [[ "$user" == *admin ]]; then
        htpasswd -cb /etc/nginx/.htpasswd $user $pass
    elif [[ "$user" == *rw ]] || [[ "$user" == *admin ]]; then
        grep -q "^${user}$" /etc/vsftpd/user_list || echo "${user}" >> /etc/vsftpd/user_list
    fi
done
echo "[4/9]: Users configured."

######################################################################################
#--------------------------------- Configure VSFTPD ---------------------------------#
######################################################################################
sudo mkdir -p /srv/ftp/nhi
sudo chown root:sharedftp /srv/ftp/nhi
sudo chmod 2775 /srv/ftp/nhi
for dept in "${DEPARTMENTS[@]}"; do
    sudo mkdir -p /srv/ftp/nhi/${dept}
    sudo chown root:sharedftp /srv/ftp/nhi/${dept}
    sudo chmod 2775 /srv/ftp/nhi/${dept}
    echo "local_root=/srv/ftp/nhi/$dept" | sudo tee "/etc/vsftpd/user_config/$user" > /dev/null # TODO: Test det her.
done
sudo mkdir -p /srv/ftp/software
sudo chown root:sharedftp /srv/ftp/software
sudo chmod 2775 /srv/ftp/software

cat <<EOF | sudo tee /etc/vsftpd.conf > /dev/null
ftpd_banner=Velkommen Til ${COMPANY_NAME^^}'s Sikre FTP Service!

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
chown_upload_mode=0775

chroot_local_user=YES
chroot_list_enable=YES
chroot_list_file=/etc/vsftpd/vsftpd.chroot

chown_uploads=YES
chown_username=ftpuser
file_open_mode=0664
local_umask=002

pasv_min_port=30000
pasv_max_port=31000
local_max_rate=1000000000

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
sed -i '/^Subsystem/s/^/#/' /etc/ssh/sshd_config
echo "[5/9]: VSFTPD Configured."
### TODO: Lav vsftpd config for hver bruger, i hver department.
### TODO: Tjek efter useradd flow, om brugerne bliver tilføjet korrekt til de rigtige gruppe.
######################################################################################
#---------------------------- Configure SSL for VSFTPD ------------------------------#
######################################################################################
if [ ! -f /etc/vsftpd/vsftpd.pem ]; then
	sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout /etc/vsftpd.pem -out /etc/vsftpd/vsftpd.pem
fi
systemctl restart vsftpd
echo "[6/9]: SSL Configured for VSFTPD."

######################################################################################
#------------------Configure logging and logrotation for VSFTPD----------------------#
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
#-------------------------------- Nginx FTP SSL  ------------------------------------#
######################################################################################
#TODO: Certifikatet skal eksporteres til DC CA
touch /etc/ssl/openssl-ip.cnf
sudo chown root:root /etc/ssl/openssl-ip.cnf
sudo chmod 644 /etc/ssl/openssl-ip.cnf
cat <<EOF | sudo tee /etc/ssl/openssl-ip.cnf > /dev/null
[ req ]
default_bits       = 2048
distinguished_name = req_distinguished_name
x509_extensions    = v3_req
prompt             = no

[ req_distinguished_name ]
CN = $HOST_IP

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
IP.1 = $HOST_IP
DNS.1 = ftp.${COMPANY_DOMAIN}
EOF
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-ip.key -out /etc/ssl/certs/nginx-ip.crt -config /etc/ssl/openssl-ip.cnf

######################################################################################
#---------------------------- Configure NGINX FTP Site ------------------------------#
######################################################################################
cat <<EOF | sudo tee /etc/nginx/sites-available/archive > /dev/null
server {
    listen 80;
    server_name ftp.${COMPANY_DOMAIN};
    return 301 https://\$host\$request_uri;
}
server {
    listen 443 ssl;
    server_name $HOST_IP ftp.${COMPANY_DOMAIN};

    ssl_certificate     /etc/ssl/certs/nginx-ip.crt;
    ssl_certificate_key /etc/ssl/private/nginx-ip.key;

    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    access_log /var/log/nginx/archive_access.log;
EOF

for dept in "${DEPARTMENTS[@]}"; do
cat <<EOF | sudo tee -a /etc/nginx/sites-available/archive > /dev/null
    location /$dept/ {
        alias /srv/ftp/nhi/${dept}/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        charset utf-8;
        disable_symlinks if_not_owner;
        auth_basic "${COMPANY_NAME^^}";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
EOF
done
cat <<EOF | sudo tee -a /etc/nginx/sites-available/archive > /dev/null
    location ~ /\. {
        deny all;
    }
    
    location /software/ {
        alias /srv/ftp/software/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        charset utf-8;
        disable_symlinks if_not_owner;
        auth_basic "${COMPANY_NAME^^}";
        auth_basic_user_file /etc/nginx/.htpasswd;
    }
}
EOF
sudo ln -sf /etc/nginx/sites-available/archive /etc/nginx/sites-enabled/archive
sudo rm /etc/nginx/sites-enabled/default
sudo chown -R root:sharedftp /srv/ftp/nhi
sudo chmod 2775 /srv/ftp/nhi
sudo sed -i 's/user .*/user ftpuser;/' /etc/nginx/nginx.conf
echo "[8/9]: NGINX Configured."

######################################################################################
#---------- Configure Cronjob for sanitizing user upload permissions ----------------#
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
#------------------------------ Reload all Services ---------------------------------#
######################################################################################
systemctl restart vsftpd || systemctl reload vsftpd
systemctl restart ufw 
systemctl restart nginx
echo "[DONE]: Reloaded all services"
sudo systemctl reload ssh

######################################################################################
#----------------------------------- Fail2Ban ----------------------------------------
######################################################################################
apt update && apt install fail2ban
