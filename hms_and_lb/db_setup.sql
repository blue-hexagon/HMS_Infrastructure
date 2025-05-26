sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD 'Kode1234\!';"

/* IOT Explorer DB Schema Initialization Script */
SET client_encoding = 'UTF8';
DROP DATABASE IF EXISTS nhi_iot_db;
DROP ROLE IF EXISTS nhi_iot_user;

CREATE USER nhi_iot_user WITH
    SUPERUSER
    ENCRYPTED PASSWORD 'Kode1234!'
    LOGIN
    CREATEDB
    CREATEROLE;

ALTER ROLE nhi_iot_user SET client_encoding TO 'UTF-8';
ALTER ROLE nhi_iot_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE nhi_iot_user SET timezone TO 'UTC';

CREATE DATABASE nhi_iot_db
  WITH OWNER nhi_iot_user
  ENCODING 'UTF8'
  LC_COLLATE='en_US.utf8'
  LC_CTYPE='en_US.utf8'
  TEMPLATE template0;
GRANT ALL PRIVILEGES ON DATABASE nhi_iot_db TO nhi_iot_user;

/* HMS DB Schema Initialization Script */
DROP DATABASE IF EXISTS hms_db;
DROP ROLE IF EXISTS hms_user;

CREATE USER hms_user WITH
    SUPERUSER
    ENCRYPTED PASSWORD 'Kode1234!'
    LOGIN
    CREATEDB
    CREATEROLE;

ALTER ROLE hms_user SET client_encoding TO 'UTF-8';
ALTER ROLE hms_user SET default_transaction_isolation TO 'read committed';
ALTER ROLE hms_user SET timezone TO 'UTC';

CREATE DATABASE hms_db
  WITH OWNER hms_user
  ENCODING 'UTF8'
  LC_COLLATE='en_US.utf8'
  LC_CTYPE='en_US.utf8'
  TEMPLATE template0;
GRANT ALL PRIVILEGES ON DATABASE hms_db TO hms_user;
