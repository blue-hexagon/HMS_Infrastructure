sudo chmod u+rwx vsftpd_installer.sh
sudo chmod u+rwx hms_installer.sh
# ---
export COMPANY_NAME="nhi"
export COMPANY_TLD="it"
export COMPANY_DOMAIN="${COMPANY_NAME}.${COMPANY_TLD}"

# ---
export DEPARTMENTS=("research" "hr" "it" )
export HOST_IP="192.168.10.37"
sudo hostnamectl set-hostname "ftp-${HOST_IP}.${COMPANY_DOMAIN}"