#!/bin/bash
# ==========================================
# 🔧 FIX DB ERROR - RenClouds TopUp
# Target Domain: tokoku.rendzzclouds.my.id
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

DOMAIN="tokoku.rendzzclouds.my.id"
WEB_ROOT="/var/www/$DOMAIN"
INC_ROOT="$WEB_ROOT/includes"
DB_NAME="renclouds_topup"
DB_USER="renclouds_user"
# Pake password yang aman (hanya huruf dan angka)
DB_PASS="RenCloudsPass123456"

echo -e "${CYAN}[1/3] Reset Database & User MySQL...${NC}"
# Hapus database dan user lama
mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"

# Bikin ulang dengan password baru
mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Masukin ulang semua tabel & data awal
mysql "$DB_NAME" << SQLEOF
CREATE TABLE users
