
#!/bin/bash
set -Eeuo pipefail

DOMAIN="tokoku.rendzzclouds.my.id"

if [[ $EUID -ne 0 ]]; then
  echo "Jalankan sebagai root: sudo -i"
  exit 1
fi

echo "======================================"
echo " RENClouds TopUp - Database Repair"
echo " Domain: $DOMAIN"
echo "======================================"

export DEBIAN_FRONTEND=noninteractive

echo "[1/6] Memeriksa paket..."
apt-get update -y
apt-get install -y php-mysql mysql-client curl

echo "[2/6] Mencari konfigurasi website..."
VHOSTS="$(nginx -T 2>/dev/null || true)"

ROOT_DIR="$(printf '%s\n' "$VHOSTS" |
  awk -v d="$DOMAIN" '
    $1=="server_name" {
      found=0
      for(i=2;i<=NF;i++) {
        gsub(";","",$i)
        if($i==d) found=1
      }
    }
    found && $1=="root" {
      gsub(";","",$2)
      print $2
      exit
    }
  ')"

if [[ -z "${ROOT_DIR:-}" || ! -d "$ROOT_DIR" ]]; then
  ROOT_DIR="$(find /var/www -type f -name index.php \
    -printf '%h\n' 2>/dev/null | head -n1 || true)"
fi

if [[ -z "${ROOT_DIR:-}" || ! -d "$ROOT_DIR" ]]; then
  echo "[ERROR] Document root tidak ditemukan."
  echo "Periksa konfigurasi Nginx untuk $DOMAIN"
  exit 1
fi

echo "[OK] Document root: $ROOT_DIR"

echo "[3/6] Memperbaiki layanan database..."
if systemctl list-unit-files | grep -q '^mysql.service'; then
  systemctl enable mysql >/dev/null 2>&1 || true
  systemctl restart mysql
elif systemctl list-unit-files | grep -q '^mariadb.service'; then
  systemctl enable mariadb >/dev/null 2>&1 || true
  systemctl restart mariadb
else
  echo "[ERROR] MySQL/MariaDB tidak ditemukan."
  exit 1
fi

echo "[4/6] Memeriksa PHP dan ekstensi..."
PHP_BIN="$(command -v php || true)"
if [[ -z "$PHP_BIN" ]]; then
  echo "[ERROR] PHP CLI belum terpasang."
  exit 1
fi

php -m | grep -qi '^mysqli$' || echo "[INFO] mysqli belum aktif."
php -m | grep -qi '^pdo_mysql$' || echo "[INFO] pdo_mysql belum aktif."

echo "PHP: $(php -v | head -n1)"
echo "PDO MySQL: $(php -r 'echo extension_loaded("pdo_mysql") ? "AKTIF" : "TIDAK AKTIF";')"
echo "MySQLi: $(php -r 'echo extension_loaded("mysqli") ? "AKTIF" : "TIDAK AKTIF";')"

echo "[5/6] Restart PHP-FPM dan Nginx..."
while read -r service; do
  [[ -z "$service" ]] && continue
  systemctl restart "$service" || true
done < <(systemctl list-units --type=service --state=running --no-legend |
  awk '{print $1}' | grep -E '^php[0-9.]+-fpm\.service$' || true)

nginx -t
systemctl reload nginx

echo "[6/6] Mencari konfigurasi database..."
find "$ROOT_DIR" -maxdepth 3 -type f \
  \( -name 'config.php' -o -name 'database.php' -o -name 'db.php' \) \
  -print

echo
echo "========== STATUS MYSQL =========="
systemctl --no-pager --full status mysql 2>/dev/null |
  head -n 12 || systemctl --no-pager --full status mariadb |
  head -n 12

echo
echo "========== LOG PHP TERAKHIR =========="
for f in /var/log/php*-fpm.log /var/log/nginx/error.log; do
  if [[ -f "$f" ]]; then
    echo "--- $f ---"
    tail -n 15 "$f"
  fi
done

echo
echo "======================================"
echo " PEMERIKSAAN SELESAI"
echo " Website: https://$DOMAIN"
echo "======================================"
