
#!/bin/bash
set -Eeuo pipefail

if [[ $EUID -ne 0 ]]; then
  echo "Jalankan sebagai root!"
  exit 1
fi

echo "=================================="
echo " RENClouds - Install Database Fix"
echo "=================================="

export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y mariadb-server mariadb-client php-mysql

systemctl enable mariadb
systemctl restart mariadb

echo
echo "[1] Memeriksa MariaDB..."
systemctl is-active mariadb

echo
echo "[2] Memeriksa koneksi database..."
mariadb -e "SELECT VERSION() AS MariaDB_Version;"

echo
echo "[3] Memeriksa PHP MySQL..."
php -r '
echo "PDO MySQL: ";
echo extension_loaded("pdo_mysql") ? "ACTIVE\n" : "NOT ACTIVE\n";
echo "MySQLi: ";
echo extension_loaded("mysqli") ? "ACTIVE\n" : "NOT ACTIVE\n";
'

echo
echo "[4] Restart PHP-FPM..."
while read -r service; do
  [[ -n "$service" ]] && systemctl restart "$service"
done < <(systemctl list-units --type=service --all --no-legend |
  awk '{print $1}' | grep -E '^php[0-9.]+-fpm\.service$' || true)

nginx -t
systemctl reload nginx

echo
echo "=================================="
echo " DATABASE SERVICE BERHASIL DIPASANG"
echo "=================================="
echo "Website: https://tokoku.rendzzclouds.my.id"
echo
echo "Database dan user aplikasi belum diubah."
