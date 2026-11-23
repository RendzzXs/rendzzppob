#!/bin/bash
# ==========================================
# 🛠️ AUTO FIX "SITE UNREACHABLE"
# Cek Nginx, Firewall, DNS, dan PHP
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; YELLOW='\033[1;33m'; NC='\033[0m'
[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

DOMAIN="asupanvgkpanel.nebuladnezar.web.id"
VPS_IP=$(curl -4 -s --max-time 5 ifconfig.me 2>/dev/null)

echo -e "${CYAN}[1/6] Cek DNS Domain...${NC}"
DOMAIN_IP=$(dig +short A "$DOMAIN" @8.8.8.8 2>/dev/null | head -1)

if [ "$VPS_IP" != "$DOMAIN_IP" ]; then
    echo -e "${RED}❌ DNS BELUM MENGARAH KE VPS!${NC}"
    echo -e "IP VPS Lu       : ${GREEN}$VPS_IP${NC}"
    echo -e "IP Domain Lu    : ${RED}$DOMAIN_IP${NC}"
    echo -e "${YELLOW}⚠️  Solusi:${NC}"
    echo -e "1. Buka Cloudflare / Domain Provider lu."
    echo -e "2. Ubah A Record domain ${WHITE}$DOMAIN${NC} ke IP ${GREEN}$VPS_IP${NC}."
    echo -e "3. Matikan Proxy Cloudflare (Awan Oranye jadi Abu-abu) sementara."
    echo -e "4. Tunggu 5-10 menit, lalu jalankan script ini lagi."
    exit 1
else
    echo -e "${GREEN}✅ DNS Sesuai ($VPS_IP)${NC}"
fi

echo -e "${CYAN}[2/6] Cek Status Nginx...${NC}"
systemctl start nginx >/dev/null 2>&1
systemctl enable nginx >/dev/null 2>&1
echo -e "${GREEN}✅ Nginx Berjalan${NC}"

echo -e "${CYAN}[3/6] Cek Status PHP-FPM...${NC}"
systemctl start php8.3-fpm >/dev/null 2>&1
systemctl enable php8.3-fpm >/dev/null 2>&1
echo -e "${GREEN}✅ PHP Berjalan${NC}"

echo -e "${CYAN}[4/6] Cek Status MariaDB...${NC}"
systemctl start mariadb >/dev/null 2>&1
systemctl enable mariadb >/dev/null 2>&1
echo -e "${GREEN}✅ Database Berjalan${NC}"

echo -e "${CYAN}[5/6] Buka Firewall (Port 80 & 443)...${NC}"
if command -v ufw >/dev/null; then
    ufw allow 80/tcp >/dev/null 2>&1
    ufw allow 443/tcp >/dev/null 2>&1
    echo -e "${GREEN}✅ UFW Firewall Dibuka${NC}"
fi
if command -v iptables >/dev/null; then
    iptables -I INPUT -p tcp --dport 80 -j ACCEPT 2>/dev/null
    iptables -I INPUT -p tcp --dport 443 -j ACCEPT 2>/dev/null
    echo -e "${GREEN}✅ Iptables Dibuka${NC}"
fi

echo -e "${CYAN}[6/6] Restart Semua Service...${NC}"
systemctl restart nginx php8.3-fpm mariadb

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ AUTO FIX SELESAI!                      ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Silakan coba buka web lu lagi:"
echo -e "${WHITE}http://$DOMAIN${NC}"
echo -e "atau"
echo -e "${WHITE}https://$DOMAIN${NC}"
