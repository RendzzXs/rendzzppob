#!/usr/bin/env bash
set -uo pipefail

LOG=/var/log/nginx_autofix.log
exec > >(tee -a "$LOG") 2>&1
echo "===== Nginx Auto-Fix $(date) ====="

# 1. Show the real reason
echo "--- nginx -t ---"
nginx -t || true
echo "--- systemctl status ---"
systemctl status nginx --no-pager -l | tail -n 30 || true
echo "--- journal ---"
journalctl -xeu nginx.service --no-pager | tail -n 40 || true

# 2. Kill conflicting web servers
for svc in apache2 httpd caddy; do
  if systemctl is-active --quiet "$svc"; then
    echo "Stopping conflicting service: $svc"
    systemctl stop "$svc"
    systemctl disable "$svc"
  fi
done

# 3. Free ports 80/443
echo "--- Ports in use ---"
ss -tlnp | grep -E ':(80|443)\b' || true

# 4. Remove default conflicting sites
rm -f /etc/nginx/sites-enabled/default
rm -f /etc/nginx/conf.d/default.conf

# 5. Drop the broken pterodactyl vhost if it references missing certs
PTERO_CONF=/etc/nginx/sites-available/pterodactyl.conf
if [ -f "$PTERO_CONF" ]; then
  echo "--- Checking pterodactyl.conf cert paths ---"
  grep -nE 'ssl_certificate' "$PTERO_CONF" || true
  # Comment out ssl lines if cert files are missing
  CERT=$(grep -oP 'ssl_certificate\s+\K[^;]+' "$PTERO_CONF" | head -n1 | tr -d ' ')
  if [ -n "${CERT:-}" ] && [ ! -f "$CERT" ]; then
    echo "Missing cert: $CERT -> temporarily disabling SSL block"
    cp "$PTERO_CONF" "${PTERO_CONF}.bak.$(date +%s)"
    sed -i 's/^\(\s*listen\s\+443.*\)/#\1/' "$PTERO_CONF"
    sed -i 's/^\(\s*ssl_/\#\1/' "$PTERO_CONF"
  fi
fi

# 6. Ensure symlink exists
if [ -f /etc/nginx/sites-available/pterodactyl.conf ]; then
  ln -sf /etc/nginx/sites-available/pterodactyl.conf /etc/nginx/sites-enabled/pterodactyl.conf
fi

# 7. Test & start
echo "--- nginx -t (after fix) ---"
if nginx -t; then
  systemctl daemon-reload
  systemctl enable nginx
  systemctl restart nginx
  sleep 2
  systemctl is-active nginx && echo "✅ nginx running"
else
  echo "❌ nginx config still broken — see errors above"
  exit 1
fi

# 8. Resume pterodactyl post-install steps if needed
if command -v php >/dev/null && [ -f /var/www/pterodactyl/artisan ]; then
  cd /var/www/pterodactyl || true
  php artisan p:environment:setup --no-interaction 2>/dev/null || true
  php artisan migrate --force 2>/dev/null || true
  php artisan config:clear 2>/dev/null || true
  php artisan cache:clear 2>/dev/null || true
  php artisan view:clear 2>/dev/null || true
  php artisan queue:restart 2>/dev/null || true
fi

echo "===== Done. Full log: $LOG ====="
