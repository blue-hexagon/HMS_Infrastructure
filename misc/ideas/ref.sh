#!/bin/bash
set -e

######################################################################################
#--------------------------------- Modular FTPES Setup ------------------------------#
######################################################################################

load_config() {
  COMPANY_NAME=${COMPANY_NAME:-"nhi"}
  COMPANY_DOMAIN=${COMPANY_DOMAIN:-"nhi.it"}
  HOST_IP=${HOST_IP:-"192.168.10.37"}
  DEPARTMENTS=(${DEPARTMENTS[@]:-"research" "it"})

  ftp_users=("${COMPANY_NAME}_admin" "${COMPANY_NAME}_ansat")
  ftp_passwords=("Admin1234!" "Kode1234!")
  for dept in "${DEPARTMENTS[@]}"; do
    ftp_users+=("${COMPANY_NAME}_${dept}_ro" "${COMPANY_NAME}_${dept}_rw")
    ftp_passwords+=("Kode1234!" "Kode1234!")
  done
  echo "[1/9]: Config loaded"
}

system_init() {
  apt update && apt upgrade -y
  apt install -y nginx-full vsftpd openssl ufw apache2-utils
  useradd -m ftpuser || true
  systemctl enable --now vsftpd ufw nginx
  echo "[2/9]: System initialized"
}

configure_ufw() {
  ufw allow 20/tcp 21/tcp 22/tcp 80/tcp 443/tcp 30000:31000/tcp
  ufw --force enable
  ufw reload
  echo "[3/9]: UFW configured"
}

create_ftp_users() {
  groupadd sharedftp || true
  usermod -aG sharedftp www-data
  mkdir -p /etc/vsftpd/user_config
  touch /etc/vsftpd/user_list
  for i in "${!ftp_users[@]}"; do
    user="${ftp_users[$i]}"
    pass="${ftp_passwords[$i]}"
    id "$user" &>/dev/null || useradd -m "$user" -s /bin/bash
    usermod -aG sharedftp "$user"
    echo "$user:$pass" | chpasswd
    [[ "$user" =~ (ro|ansat|admin) ]] && htpasswd -cb /etc/nginx/.htpasswd "$user" "$pass"
    [[ "$user" =~ (rw|admin) ]] && grep -q "^$user$" /etc/vsftpd/user_list || echo "$user" >> /etc/vsftpd/user_list
  done
  echo "[4/9]: FTP users created"
}

configure_vsftpd() {
  mkdir -p /srv/ftp/nhi /srv/ftp/software
  chown root:sharedftp /srv/ftp/nhi /srv/ftp/software
  chmod 2775 /srv/ftp/nhi /srv/ftp/software
  for dept in "${DEPARTMENTS[@]}"; do
    mkdir -p "/srv/ftp/nhi/$dept"
    chown root:sharedftp "/srv/ftp/nhi/$dept"
    chmod 2775 "/srv/ftp/nhi/$dept"
  done

  cat <<EOF > /etc/vsftpd.conf
ftpd_banner=Velkommen Til ${COMPANY_NAME^^}'s Sikre FTP Service!
... # shortened for clarity — same as your original config
EOF

  echo "${COMPANY_NAME}_admin" > /etc/vsftpd/vsftpd.chroot
  sed -i '/^Subsystem/s/^/#/' /etc/ssh/sshd_config
  echo "[5/9]: VSFTPD configured"
}

configure_vsftpd_ssl() {
  [[ -f /etc/vsftpd/vsftpd.pem ]] || \
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
      -keyout /etc/vsftpd.pem -out /etc/vsftpd/vsftpd.pem
  systemctl restart vsftpd
  echo "[6/9]: VSFTPD SSL configured"
}

setup_log_rotation() {
  touch /var/log/vsftpd.log
  chown ftpuser:adm /var/log/vsftpd.log
  chmod 640 /var/log/vsftpd.log
  tee /etc/logrotate.d/vsftpd > /dev/null <<EOF
/var/log/vsftpd.log {
  weekly
  rotate 4
  compress
  missingok
  notifempty
}
EOF
  echo "[7/9]: Logrotate configured"
}

generate_nginx_ssl() {
  cat <<EOF > /etc/ssl/openssl-ip.cnf
[ req ]
default_bits = 2048
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = $HOST_IP

[ v3_req ]
subjectAltName = @alt_names

[ alt_names ]
IP.1 = $HOST_IP
DNS.1 = ftp.${COMPANY_DOMAIN}
EOF

  openssl req -x509 -nodes -days 365 \
    -newkey rsa:2048 \
    -keyout /etc/ssl/private/nginx-ip.key \
    -out /etc/ssl/certs/nginx-ip.crt \
    -config /etc/ssl/openssl-ip.cnf
}

configure_nginx() {
  cat <<EOF > /etc/nginx/sites-available/archive
server {
  listen 80;
  server_name ftp.${COMPANY_DOMAIN};
  return 301 https://\$host\$request_uri;
}

server {
  listen 443 ssl;
  server_name $HOST_IP ftp.${COMPANY_DOMAIN};
  ssl_certificate /etc/ssl/certs/nginx-ip.crt;
  ssl_certificate_key /etc/ssl/private/nginx-ip.key;
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers HIGH:!aNULL:!MD5;
  ssl_prefer_server_ciphers on;
EOF

  for dept in "${DEPARTMENTS[@]}"; do
    cat <<EOF >> /etc/nginx/sites-available/archive
  location /$dept/ {
    alias /srv/ftp/nhi/$dept/;
    autoindex on;
    auth_basic "${COMPANY_NAME^^}";
    auth_basic_user_file /etc/nginx/.htpasswd;
  }
EOF
  done

  cat <<EOF >> /etc/nginx/sites-available/archive
  location /software/ {
    alias /srv/ftp/software/;
    autoindex on;
    auth_basic "${COMPANY_NAME^^}";
    auth_basic_user_file /etc/nginx/.htpasswd;
  }
  location ~ /\\. {
    deny all;
  }
}
EOF

  ln -sf /etc/nginx/sites-available/archive /etc/nginx/sites-enabled/archive
  rm -f /etc/nginx/sites-enabled/default
  sed -i 's/user .*/user ftpuser;/' /etc/nginx/nginx.conf
  echo "[8/9]: NGINX configured"
}

setup_cronjob() {
  tee /usr/local/bin/fix-ftp-perms.sh > /dev/null <<'EOF'
#!/bin/bash
chown -R ftpuser:sharedftp /srv/ftp/nhi
chmod -R g+rwx /srv/ftp/nhi
find /srv/ftp/nhi -type d -exec chmod 2775 {} \;
EOF
  chmod +x /usr/local/bin/fix-ftp-perms.sh
  (crontab -l 2>/dev/null; echo "0 1 * * * /usr/local/bin/fix-ftp-perms.sh") | crontab -
  echo "[9/9]: Cronjob configured"
}

reload_services() {
  systemctl restart vsftpd
  systemctl restart nginx
  systemctl reload ssh
  echo "[DONE]: Services reloaded"
}

setup_fail2ban() {
  apt install -y fail2ban
}

######################################################################################
#---------------------------------- Run Script --------------------------------------#
######################################################################################
main "$@"
