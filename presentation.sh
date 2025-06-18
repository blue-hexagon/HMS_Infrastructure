cat <<EOF | sudo tee /etc/nginx/sites-available/archive >/dev/null
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
    cat <<EOF | sudo tee -a /etc/nginx/sites-available/archive >/dev/null
    location /$dept/ {
        alias /srv/ftp/nhi/${dept}/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        charset utf-8;
        disable_symlinks if_not_owner;
        auth_basic "${COMPANY_NAME^^}";
        auth_basic_user_file /etc/nginx/.htpasswd_$dept;
        add_before_body /autoindex.css;
        add_after_body /banner.html;
    }
EOF
done
cat <<EOF | sudo tee -a /etc/nginx/sites-available/archive >/dev/null
    location ~ /\. {
        deny all;
    }
    
    location / {
         root /srv/ftp/nhi;
         index index.html;
     }
    
    location /software/ {
        alias /srv/ftp/software/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        charset utf-8;
        disable_symlinks if_not_owner;
        auth_basic "${COMPANY_NAME^^}";
        auth_basic_user_file /etc/nginx/.htpasswd_ansat;
    }
}
EOF