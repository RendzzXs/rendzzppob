#!/bin/bash
# ==========================================
# 🧹 RenClouds - Total Cleanup Script
# Fitur: Hapus semua web lama, DB, & Service Bot
# (Nginx, PHP, MySQL, Node.js TETAP AMAN)
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

echo -e "${YELLOW}⚠️ PERINGATAN KERAS!${NC}"
echo -e "Script ini akan MENGHAPUS SEMUA FILE WEB & DATABASE yang pernah kita buat."
echo -e "Termasuk: RenClouds, RenMail, RenStalker, RenAPK Bot, PPOB."
echo -e "Nginx, PHP, MySQL, Node.js TIDAK akan dihapus."
echo ""
read -p "👉 Ketik 'YES' (huruf besar) untuk melanjutkan: " KONFIRMASI
if [ "$KONFIRMASI" != "YES" ]; then
    echo -e "${RED}❌ Dibatalkan.${NC}"
    exit 1
fi

echo -e "\n${CYAN}[1/5] Menghapus Folder Web di /var/www/...${NC}"
# Hapus semua folder di dalam /var/www kecuali default
find /var/www -mindepth 1 -maxdepth 1 -type d ! -name "html" -exec rm -rf {} + 2>/dev/null
echo -e "${GREEN}✅ Folder web dibersihkan.${NC}"

echo -e "\n${CYAN}[2/5] Menghapus Folder Backend/Node.js di /opt/...${NC}"
# Hapus folder proyek nodejs yang pernah kita buat
rm -rf /opt/renstalker /opt/tempmail /opt/renapk /opt/renapk-bot /opt/renmail
echo -e "${GREEN}✅ Folder backend dibersihkan.${NC}"

echo -e "\n${CYAN}[3/5] Menghapus Service Systemd (Bot & API)...${NC}"
# Stop dan hapus service yang berkaitan
SERVICES=("renstalker" "tempmail" "renapkbot" "renmail")
for svc in "${SERVICES[@]}"; do
    if systemctl list-units --full -all | grep -Fq "$svc.service"; then
        systemctl stop "$svc" 2>/dev/null
        systemctl disable "$svc" 2>/dev/null
        rm -f "/etc/systemd/system/$svc.service"
    fi
done
systemctl daemon-reload
echo -e "${GREEN}✅ Service dibersihkan.${NC}"

echo -e "\n${CYAN}[4/5] Menghapus Konfigurasi Nginx Sisa...${NC}"
# Hapus symlink di sites-enabled (BUKAN package nginx-nya)
rm -f /etc/nginx/sites-enabled/* 2>/dev/null
# Bikin default balik ke halaman default nginx
cat > /etc/nginx/sites-enabled/default << 'NGINXEOF'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.html index.htm;
    server_name _;
    location / {
        try_files $uri $uri/ =404;
    }
}
NGINXEOF
# Hapus config spesifik domain di sites-available
find /etc/nginx/sites-available -type f ! -name "default" -exec rm -f {} + 2>/dev/null
systemctl reload nginx
echo -e "${GREEN}✅ Konfigurasi Nginx dibersihkan (kembali ke default).${NC}"

echo -e "\n${CYAN}[5/5] Menghapus Database Sisa...${NC}"
# List nama database yang kita pernah buat
DBS=("renclouds_db" "bpobku_db" "renclouds_topup" "mail_db")
for db in "${DBS[@]}"; do
    mysql -e "DROP DATABASE IF EXISTS \`$db\`;" 2>/dev/null
done
# Hapus user database yang kita buat
DBS_USER=("ren_user" "bpob_user" "renclouds_user")
for usr in "${DBS_USER[@]}"; do
    mysql -e "DROP USER IF EXISTS '$usr'@'localhost';" 2>/dev/null
done
mysql -e "FLUSH PRIVILEGES;"
echo -e "${GREEN}✅ Database dibersihkan.${NC}"

echo -e "\n${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ PEMBERSIHAN TOTAL SELESAI!                 ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Server lo sekarang dalam keadaan BERSIH (Fresh)."
echo -e "Nginx, PHP, MySQL, dan Node.js masih terinstall dan siap dipake lagi."
echo ""
echo -e "${YELLOW}💡 Kalau lo mau install script baru, tinggal jalanin script installernya aja tanpa takut konflik.${NC}"
