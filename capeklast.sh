#!/bin/bash
# ==========================================
# 🛠️ FIX KILAT "WELCOME TO NGINX"
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'

# Pastikan lu masukin domain yang bener di sini
DOMAIN="asupanvgkpanel.nebuladnezar.web.id"
WEB_ROOT="/var/www/$DOMAIN"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

echo -e "${CYAN}[1/3] Hapus Config Nginx Default...${NC}"
# Ini biang keroknya
rm -f /etc/nginx/sites-enabled/default
echo -e "${GREEN}  ✅ Default Dihapus${NC}"

echo -e "${CYAN}[2/3] Bikin Config Domain...${NC}"
# Bikin folder web kalau belum ada
mkdir -p "$WEB_ROOT"
# Bikin file index.php sementara (biar ga 404)
if [ ! -f "$WEB_ROOT/index.php" ]; then
    echo "<?php echo 'Web Asupan VGK siap di-setup!'; ?>" > "$WEB_ROOT/index.php"
fi

# Bikin config Nginx baru
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN;
    root $WEB_ROOT;
    index index.php index.html;

    location ~ /\.ht { deny all; }
    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }
}
NGINXEOF

# Aktifkan config
ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
nginx -t >/dev/null 2>&1 && systemctl reload nginx
echo -e "${GREEN}  ✅ Config Domain OK${NC}"

echo -e "${CYAN}[3/3] Restart PHP & Nginx...${NC}"
chown -R www-data:www-data "$WEB_ROOT"
systemctl restart php8.3-fpm nginx

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ FIX SELESAI!                           ║${NC}"
echo -e "${GREEN}║  'Welcome to Nginx' Harusnya Udah Hilang   ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Coba buka: ${WHITE}http://$DOMAIN${NC}"
echo -e "Harusnya sekarang muncul tulisan ${GREEN}'Web Asupan VGK siap di-setup!'${NC}"
echo -e "Kalau udah muncul, berarti Nginx lu udah bener."
echo -e "Langkah selanjutnya tinggal jalanin ${WHITE}Script Installer v6.0${NC} buat masukin file webnya."
