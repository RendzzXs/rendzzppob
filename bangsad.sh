
#!/bin/bash
# ==========================================
# RENDZZ OFFICIAL - VPS DEEP CLEAN
# NO REBOOT | NO SYSTEM RESTART
# Ubuntu 22.04 / 24.04
# ==========================================

set -Eeuo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

LOG="/var/log/rendzz-deep-clean.log"

if [[ $EUID -ne 0 ]]; then
    echo "Run this script as root."
    exit 1
fi

echo -e "${RED}"
echo "=========================================="
echo "       RENDZZ VPS DEEP CLEAN"
echo "=========================================="
echo "WARNING: Panel/database/config data will be deleted."
echo -e "${NC}"

read -r -p "Type CLEAN-VPS to continue: " CONFIRM

if [[ "$CONFIRM" != "CLEAN-VPS" ]]; then
    echo "Cancelled."
    exit 0
fi

exec > >(tee -a "$LOG") 2>&1

echo -e "${CYAN}[1/9] Stopping related services...${NC}"

for SERVICE in nginx apache2 php8.1-fpm php8.2-fpm php8.3-fpm \
php8.4-fpm mariadb mysql redis-server pteroq wings; do
    systemctl stop "$SERVICE" 2>/dev/null || true
    systemctl disable "$SERVICE" 2>/dev/null || true
done

echo -e "${CYAN}[2/9] Removing Pterodactyl services...${NC}"

rm -f /etc/systemd/system/pteroq.service
rm -f /etc/systemd/system/wings.service

systemctl daemon-reload

echo -e "${CYAN}[3/9] Removing panel and Wings files...${NC}"

rm -rf /var/www/pterodactyl
rm -rf /etc/pterodactyl
rm -rf /var/lib/pterodactyl
rm -rf /var/log/pterodactyl
rm -rf /var/log/ptero_auto_install.log
rm -f /usr/local/bin/wings

echo -e "${CYAN}[4/9] Removing Nginx configurations...${NC}"

rm -rf /etc/nginx/sites-enabled/*
rm -rf /etc/nginx/sites-available/*
rm -rf /etc/nginx/conf.d/*

echo -e "${CYAN}[5/9] Removing Pterodactyl packages...${NC}"

apt-get purge -y \
nginx nginx-common nginx-core nginx-full \
apache2 apache2-bin apache2-data apache2-utils \
'php8.1*' 'php8.2*' 'php8.3*' 'php8.4*' \
mariadb-server mariadb-client mariadb-common \
mysql-server mysql-client mysql-common \
redis-server redis-tools \
certbot python3-certbot-nginx \
composer nodejs npm 2>/dev/null || true

echo -e "${CYAN}[6/9] Removing related configuration...${NC}"

rm -rf /etc/php
rm -rf /etc/letsencrypt
rm -rf /etc/redis
rm -rf /etc/mysql
rm -rf /var/lib/mysql
rm -rf /var/log/mysql
rm -rf /var/log/nginx
rm -rf /var/cache/nginx

echo -e "${CYAN}[7/9] Cleaning APT...${NC}"

apt-get autoremove --purge -y
apt-get autoclean -y
apt-get clean

echo -e "${CYAN}[8/9] Refreshing systemd and package state...${NC}"

systemctl daemon-reload
dpkg --configure -a

echo -e "${CYAN}[9/9] Final verification...${NC}"

echo ""
echo -e "${GREEN}========== CLEAN COMPLETED ==========${NC}"

echo "OS:"
cat /etc/os-release | grep PRETTY_NAME

echo ""
echo "Disk:"
df -h /

echo ""
echo "Remaining related services:"
systemctl list-unit-files --type=service | grep -Ei \
'nginx|apache|ptero|wings|mysql|mariadb|redis' || true

echo ""
echo "Log: $LOG"
echo -e "${GREEN}VPS CLEANING FINISHED.${NC}"
echo "No reboot or system restart was issued."
