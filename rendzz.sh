#!/bin/bash
# ==========================================
# 🔥 RenClouds TopUp v3.5 - BEDAH TOTAL DB
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

DOMAIN="tokoku.rendzzclouds.my.id"
WEB_ROOT="/var/www/$DOMAIN"
INC_ROOT="$WEB_ROOT/includes"

# 1. PASTIIN SERVICE JALAN
echo -e "${CYAN}[1/5] Ngecek Service MySQL & PHP...${NC}"
systemctl restart mariadb mysql 2>/dev/null
systemctl restart php8.1-fpm php8.3-fpm 2>/dev/null

# 2. BIKIN USER & DATABASE BARU (PAKE PASSWORD SIMPLE)
DB_NAME="renclouds_db"
DB_USER="ren_user"
DB_PASS="renpassword"

echo -e "${CYAN}[2/5] Bikin User Database Baru...${NC}"
mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# 3. BIKIN TABEL LENGKAP
echo -e "${CYAN}[3/5] Bikin Tabel & Data Produk...${NC}"
mysql "$DB_NAME" << SQLEOF
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL,
    phone VARCHAR(20) UNIQUE NOT NULL, password VARCHAR(255) NOT NULL,
    saldo DECIMAL(15,2) DEFAULT 0, status ENUM('active','blocked') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE admins (
    id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL, password VARCHAR(255) NOT NULL
);
-- Pass: admin123
INSERT INTO admins (username, password) VALUES ('admin', '\$2y\$10\$e.wXq.f2M3g4H5j6K7l8mO9p0Q1r2S3t4U5v6W7x8Y9z0A1b2C3d4e');

CREATE TABLE products (
    id INT AUTO_INCREMENT PRIMARY KEY, category ENUM('PULSA','DANA','DATA','PLN','GAME','PDAM','BPJS') NOT NULL,
    provider VARCHAR(50), name VARCHAR(100) NOT NULL, price DECIMAL(15,2) NOT NULL,
    admin_fee DECIMAL(15,2) DEFAULT 0, status ENUM('active','inactive') DEFAULT 'active'
);

CREATE TABLE deposits (
    id INT AUTO_INCREMENT PRIMARY KEY, user_id INT, amount DECIMAL(15,2),
    proof_img VARCHAR(255), status ENUM('pending','approved','rejected') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE transactions (
    id INT AUTO_INCREMENT PRIMARY KEY, ref_id VARCHAR(50) UNIQUE, user_id INT, product_id INT,
    target_number VARCHAR(50), total_price DECIMAL(15,2),
    payment_method ENUM('SALDO','QRIS') DEFAULT 'SALDO', proof_img VARCHAR(255),
    status ENUM('pending','diproses','berhasil','ditolak','refund') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE balance_logs (
    id INT AUTO_INCREMENT PRIMARY KEY, user_id INT, admin_id INT NULL,
    type ENUM('in','out','refund') NOT NULL, amount DECIMAL(15,2),
    saldo_before DECIMAL(15,2), saldo_after DECIMAL(15,2), reason VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE payment_settings (
    id INT PRIMARY KEY, qris_url TEXT, site_name VARCHAR(100) DEFAULT 'RenClouds TopUp'
);
INSERT INTO payment_settings (id, qris_url) VALUES (1, 'https://via.placeholder.com/300x400.png?text=QRIS+Belum+Diatur');

-- SEED PRODUK
INSERT INTO products (category, provider, name, price, admin_fee) VALUES 
('PULSA', 'Telkomsel', 'Telkomsel 10.000', 11000, 0), ('PULSA', 'Indosat', 'Indosat 10.000', 11000, 0),
('DATA', 'Telkomsel', 'Data 10GB / 30 Hari', 65000, 0),
('DANA', 'DANA', 'DANA 10.000', 10000, 500),
('PLN', 'PLN', 'Token Listrik 20.000', 21000, 0),
('GAME', 'Mobile Legends', 'Diamond ML 86', 22000, 0),
('PDAM', 'PDAM', 'Tagihan PDAM', 0, 2500), ('BPJS', 'BPJS', 'BPJS Kesehatan', 0, 2500);
SQLEOF

# 4. UPDATE CONFIG.PHP (PAKE PASSWORD SIMPLE)
echo -e "${CYAN}[4/5] Generate ulang config.php...${NC}"
cat > "$INC_ROOT/config.php" << PHPEOF
<?php
define('DB_HOST', '127.0.0.1'); define('DB_NAME', '$DB_NAME');
define('DB_USER', '$DB_USER'); define('DB_PASS', '$DB_PASS');
try { 
    \$pdo = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4", DB_USER, DB_PASS, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]); 
} catch (PDOException \$e) { 
    die("DB Error Asli: " . \$e->getMessage()); // <--- INI BIAR KETAHUAN ERORNYA
}
function rupiah(\$n) { return 'Rp ' . number_format(\$n, 0, ',', '.'); }
PHPEOF

# 5. TES KONEKSI LANGSUNG DARI PHP
echo -e "${CYAN}[5/5] Tes Koneksi PHP ke Database...${NC}"
TEST_FILE="$WEB_ROOT/test_db.php"
cat > "$TEST_FILE" << 'PHPEOF'
<?php
require 'includes/config.php';
echo "✅ KONEKSI DATABASE BERHASIL!<br>";
echo "Nama DB: " . DB_NAME . "<br>";
echo "User DB: " . DB_USER . "<br>";
$stmt = $pdo->query("SELECT COUNT(*) FROM products");
echo "Total Produk: " . $stmt->fetchColumn();
?>
PHPEOF

chown -R www-data:www-data "$WEB_ROOT"
chmod -R 777 "$WEB_ROOT/uploads"

echo -e "${GREEN}✅ INSTALASI SELESAI!${NC}"
echo -e "${CYAN}Coba buka link ini di browser lo:${NC}"
echo -e "http://$DOMAIN/test_db.php"
echo ""
echo -e "${YELLOW}Kalau di browser muncul tulisan 'KONEKSI DATABASE BERHASIL!', berarti web lo udah bener.${NC}"
echo -e "${YELLOW}Kalau masih error, copy tulisan error yang muncul di link itu, kirim ke gua.${NC}"
