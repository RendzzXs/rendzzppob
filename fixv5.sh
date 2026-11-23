
#!/bin/bash
set +e

DOMAIN="tokoku.rendzzclouds.my.id"
ROOT="/var/www/tokoku.rendzzclo"

echo "=========================================="
echo " RENClouds TopUp - AUTO DB DIAGNOSTIC"
echo "=========================================="

echo
echo "[1] DATABASE SERVICE"
systemctl is-active mariadb
mariadb -Nse "SELECT VERSION();" 2>&1

echo
echo "[2] DATABASE YANG TERSEDIA"
mariadb -e "SHOW DATABASES;" 2>&1

echo
echo "[3] USER DATABASE"
mariadb -e "SELECT User,Host FROM mysql.user;" 2>&1

echo
echo "[4] MENCARI KONFIGURASI APLIKASI"
find "$ROOT" -maxdepth 4 -type f \
  \( -name "*.php" -o -name ".env" \) \
  ! -path "*/vendor/*" \
  ! -path "*/uploads/*" \
  -print 2>/dev/null

echo
echo "[5] KONFIGURASI DB (PASSWORD DISENSOR)"
grep -RniE \
'DB_HOST|DB_NAME|DB_USER|DB_PASS|DB_DATABASE|DB_USERNAME|DB_PASSWORD|dbname|mysqli_connect|new PDO|localhost' \
"$ROOT" --include="*.php" --include=".env" \
--exclude-dir=vendor --exclude-dir=uploads 2>/dev/null |
sed -E \
's/(DB_PASS(WOR)?D?[^=]*=|DB_PASSWORD[^,]*,|password[[:space:]]*=[[:space:]]*)[^,;)]*/\1[REDACTED]/Ig' |
head -n 100

echo
echo "[6] PHP VERSION"
php -v | head -n 2
php -m | grep -Ei 'mysqli|pdo_mysql'

echo
echo "[7] PHP-FPM STATUS"
systemctl list-units --type=service --all --no-legend |
grep -E 'php.*fpm' || true

echo
echo "[8] NGINX CONFIGURATION"
nginx -t 2>&1
nginx -T 2>/dev/null |
grep -E 'server_name|root |fastcgi_pass' |
head -n 50

echo
echo "[9] MENCARI PESAN DB ERROR DI SOURCE"
grep -RniE 'DB Error|Database Error|Connection failed|Access denied|Unknown database|SQLSTATE' \
"$ROOT" --include="*.php" \
--exclude-dir=vendor --exclude-dir=uploads 2>/dev/null |
head -n 60

echo
echo "[10] ERROR LOG TERAKHIR"
for f in /var/log/nginx/error.log \
         /var/log/php*-fpm.log \
         /var/log/mysql/error.log \
         /var/log/mysql/*.log; do
  if [[ -f "$f" ]]; then
    echo "---- $f ----"
    tail -n 20 "$f"
  fi
done

echo
echo "[11] TEST WEBSITE"
curl -k -sS -L --max-time 20 \
  -o /tmp/renclouds-response.html \
  -w "HTTP STATUS: %{http_code}\nTIME: %{time_total}s\n" \
  "https://$DOMAIN"

echo
echo "RESPONS HTML:"
head -c 500 /tmp/renclouds-response.html 2>/dev/null
echo

echo
echo "=========================================="
echo " DIAGNOSTIC SELESAI"
echo "=========================================="
