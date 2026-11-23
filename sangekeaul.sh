
#!/bin/bash
set -Eeuo pipefail

DOMAIN="tokoku.rendzzclouds.my.id"
APP="/var/www/tokoku.rendzzclo"
WEBROOT="$APP/public"
CONFIG="$APP/includes/config.php"
PHP_VER="8.1"

if [[ $EUID -ne 0 ]]; then
  echo "Jalankan sebagai root."
  exit 1
fi

if [[ ! -f "$CONFIG" || ! -d "$WEBROOT" ]]; then
  echo "[ERROR] Source aplikasi tidak ditemukan: $APP"
  exit 1
fi

echo "=========================================="
echo " RENClouds TopUp - AUTO REPAIR"
echo "=========================================="

BACKUP="/root/renclouds-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP"
cp -a "$CONFIG" "$BACKUP/config.php"

echo "[1/7] Membaca konfigurasi database..."

DB_VALUES="$(python3 - "$CONFIG" <<'PY'
import re,sys
s=open(sys.argv[1]).read()
for key in ("DB_HOST","DB_NAME","DB_USER","DB_PASS"):
    m=re.search(r"define\s*\(\s*['\"]"+key+r"['\"]\s*,\s*(['\"])(.*?)\1\s*\)",s)
    if not m:
        print("ERROR: "+key+" tidak ditemukan",file=sys.stderr)
        sys.exit(1)
    print(m.group(2))
PY
)"

mapfile -t DB < <(printf '%s\n' "$DB_VALUES")
DB_HOST="${DB[0]}"
DB_NAME="${DB[1]}"
DB_USER="${DB[2]}"
DB_PASS="${DB[3]}"

if [[ "$DB_HOST" != "127.0.0.1" && "$DB_HOST" != "localhost" ]]; then
  echo "[ERROR] DB_HOST bukan database lokal: $DB_HOST"
  echo "Script dihentikan agar tidak mengubah database eksternal."
  exit 1
fi

echo "[OK] Database: $DB_NAME"
echo "[OK] User: $DB_USER"
echo "[OK] Password tidak ditampilkan."

echo "[2/7] Memastikan MariaDB terpasang..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y mariadb-server mariadb-client python3

echo "[3/7] Mengaktifkan database..."
systemctl unmask mariadb.service 2>/dev/null || true
systemctl enable mariadb
systemctl restart mariadb

for i in {1..20}; do
  if mariadb-admin ping --silent 2>/dev/null; then
    break
  fi
  sleep 2
done

if ! mariadb-admin ping --silent 2>/dev/null; then
  echo "[ERROR] MariaDB gagal berjalan."
  journalctl -u mariadb -n 60 --no-pager
  exit 1
fi

echo "[4/7] Memastikan database dan akses user..."
python3 - "$DB_NAME" "$DB_USER" "$DB_PASS" <<'PY' >/root/renclouds-db-setup.sql
import sys
name,user,password=sys.argv[1:4]

def quote(s):
    return "'" + s.replace("\\","\\\\").replace("'","\\'") + "'"

for value in (name,user):
    if not value or len(value)>64:
        raise SystemExit("Nama database/user tidak valid")

print("CREATE DATABASE IF NOT EXISTS `"+name.replace("`","``")+"` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;")
print("CREATE USER IF NOT EXISTS "+quote(user)+"@'127.0.0.1' IDENTIFIED BY "+quote(password)+";")
print("ALTER USER "+quote(user)+"@'127.0.0.1' IDENTIFIED BY "+quote(password)+";")
print("GRANT ALL PRIVILEGES ON `"+name.replace("`","``")+"`.* TO "+quote(user)+"@'127.0.0.1';")
print("FLUSH PRIVILEGES;")
PY

chmod 600 /root/renclouds-db-setup.sql
mariadb < /root/renclouds-db-setup.sql
rm -f /root/renclouds-db-setup.sql

echo "[5/7] Memastikan PHP-FPM 8.1 memiliki MySQL..."
apt-get install -y "php${PHP_VER}-mysql"

systemctl enable "php${PHP_VER}-fpm"
systemctl restart "php${PHP_VER}-fpm"

if ! "/usr/bin/php${PHP_VER}" -m 2>/dev/null | grep -qi pdo_mysql; then
  echo "[ERROR] PDO MySQL tidak aktif di PHP $PHP_VER."
  exit 1
fi

echo "[6/7] Memperbaiki root domain Nginx..."
python3 - "$DOMAIN" "$WEBROOT" <<'PY'
import sys,re,glob,os,shutil,time

domain,root=sys.argv[1:3]
files=set(glob.glob("/etc/nginx/sites-enabled/*"))
files.update(glob.glob("/etc/nginx/conf.d/*.conf"))
changed=0

for path in files:
    if not os.path.isfile(path):
        continue
    try:
        original=open(path).read()
    except Exception:
        continue

    matches=list(re.finditer(r'\bserver\s*\{',original))
    updated=original

    for match in reversed(matches):
        start=match.start()
        brace=original.find("{",match.start())
        depth=0
        end=None

        for i in range(brace,len(original)):
            if original[i]=="{":
                depth+=1
            elif original[i]=="}":
                depth-=1
                if depth==0:
                    end=i+1
                    break

        if end is None:
            continue

        block=original[start:end]
        names=re.search(r'\bserver_name\s+([^;]+);',block)

        if not names:
            continue

        if domain not in names.group(1).split():
            continue

        newblock=re.sub(
            r'(?m)^(\s*root\s+)[^;]+;',
            lambda m:m.group(1)+root+";",
            block
        )

        newblock=re.sub(
            r'fastcgi_pass\s+unix:/var/run/php/php[0-9.]+-fpm\.sock;',
            'fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;',
            newblock
        )

        updated=updated[:start]+newblock+updated[end:]
        changed+=1

    if updated!=original:
        backup=path+".renclouds-backup-"+str(int(time.time()))
        shutil.copy2(path,backup)
        with open(path,"w") as f:
            f.write(updated)
        print("[OK] Config diperbaiki:",path)

if changed==0:
    print("[WARNING] Server block domain tidak ditemukan.")
    print("Jangan membuat konfigurasi duplikat otomatis.")
PY

echo "[7/7] Validasi dan restart layanan..."
nginx -t
systemctl restart nginx

echo
echo "========== HASIL DATABASE =========="
mariadb -Nse "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME='$DB_NAME';"

echo
echo "========== TABEL APLIKASI =========="
mariadb "$DB_NAME" -e "SHOW TABLES;"

echo
echo "========== PHP-FPM =========="
systemctl is-active "php${PHP_VER}-fpm"

echo
echo "========== PORT WEBSITE =========="
ss -lntp | grep -E ':(80|443)[[:space:]]' || true

echo
echo "========== HTTP TEST =========="
curl -sS -o /dev/null -w "HTTP: %{http_code}\n" \
  --max-time 15 "http://$DOMAIN" || true

echo
echo "========== HTTPS TEST =========="
curl -k -sS -o /dev/null -w "HTTPS: %{http_code}\n" \
  --max-time 15 "https://$DOMAIN" || true

echo
echo "=========================================="
echo " PERBAIKAN SELESAI"
echo " Backup: $BACKUP"
echo " Website: https://$DOMAIN"
echo "=========================================="
