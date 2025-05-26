#!/bin/bash
ALLOW_REMOTE=true

sudo apt update
sudo apt install -y postgresql postgresql-contrib
PG_VERSION=$(ls /etc/postgresql)
PG_CONF_DIR="/etc/postgresql/${PG_VERSION}/main"

sudo systemctl enable postgresql
sudo systemctl restart postgresql

if [ "$ALLOW_REMOTE" = true ]; then
    sudo sed -i "s/^#listen_addresses = 'localhost'/listen_addresses = '*'/g" \
        "$PG_CONF_DIR/postgresql.conf"

    # Only append to pg_hba.conf if not already present
    if ! grep -q "0.0.0.0/0" "$PG_CONF_DIR/pg_hba.conf"; then
        echo "host    all             all             0.0.0.0/0               md5" | sudo tee -a "$PG_CONF_DIR/pg_hba.conf"
    fi

    sudo systemctl restart postgresql
fi

sudo -u postgres psql -f db_setup.sql