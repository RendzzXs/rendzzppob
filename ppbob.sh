#!/bin/bash
# ==========================================
# 🚀 RenClouds OTP v6.0 - Ultimate Edition
# Target Domain: tokoku.rendzzclouds.my.id
# ==========================================

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
[[ $EUID -ne 0 ]] && { echo -e "${RED}❌ Harus root!${NC}"; exit 1; }

DOMAIN="tokoku.rendzzclouds.my.id"
WEB_ROOT="/var/www/$DOMAIN/public"
ADMIN_ROOT="/var/www/$DOMAIN/admin"
INC_ROOT="/var/www/$DOMAIN/includes"
UPLOAD_ROOT="/var/www/$DOMAIN/uploads/payment-proof"
DB_NAME="renclouds_otp"
DB_USER="renclouds_user"
DB_PASS="RenCloudsPass123456"
NGINX_CONF="/etc/nginx/sites-available/$DOMAIN"

echo -e "${CYAN}[1/6] Setup Database...${NC}"
mysql -e "DROP DATABASE IF EXISTS \`$DB_NAME\`;"
mysql -e "DROP USER IF EXISTS '$DB_USER'@'localhost';"
mysql -e "CREATE DATABASE \`$DB_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
mysql -e "GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'localhost';"
mysql -e "FLUSH PRIVILEGES;"

# Hash Password Admin 'Ren11#'
ADMIN_HASH=$(php -r 'echo password_hash("Ren11#", PASSWORD_DEFAULT);')

mysql "$DB_NAME" << SQLEOF
CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL, saldo DECIMAL(15,2) DEFAULT 0, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE admins (
    id INT AUTO_INCREMENT PRIMARY KEY, username VARCHAR(50) UNIQUE NOT NULL, password VARCHAR(255) NOT NULL
);
INSERT INTO admins (username, password) VALUES ('admin', '$ADMIN_HASH');

CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY, user_id INT, service VARCHAR(50), country VARCHAR(50),
    phone_number VARCHAR(50), price DECIMAL(15,2), otp_code VARCHAR(20) DEFAULT NULL,
    status ENUM('pending','active','completed','cancelled') DEFAULT 'pending', created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE deposits (
    id INT AUTO_INCREMENT PRIMARY KEY, user_id INT, amount DECIMAL(15,2),
    proof_img VARCHAR(255), status ENUM('pending','approved','rejected') DEFAULT 'pending', created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE settings (
    id INT PRIMARY KEY, qris_url TEXT, api_url VARCHAR(255), api_key VARCHAR(255)
);
INSERT INTO settings (id, qris_url, api_url, api_key) VALUES (1, 'https://upload.wikimedia.org/wikipedia/commons/thumb/d/d0/QR_code_for_mobile_English_Wikipedia.svg/1200px-QR_code_for_mobile_English_Wikipedia.svg.png', 'https://api.siputzx.my.id/api/otp', 'YOUR_API_KEY');
SQLEOF

echo -e "${CYAN}[2/6] Generate File Web & CSS Mewah...${NC}"
rm -rf "/var/www/$DOMAIN"
mkdir -p "$WEB_ROOT/assets" "$ADMIN_ROOT" "$INC_ROOT" "$UPLOAD_ROOT"
chmod -R 777 "$UPLOAD_ROOT"

cat > "$INC_ROOT/config.php" << PHPEOF
<?php
define('DB_HOST', '127.0.0.1'); define('DB_NAME', '$DB_NAME');
define('DB_USER', '$DB_USER'); define('DB_PASS', '$DB_PASS');
try { \$pdo = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8mb4", DB_USER, DB_PASS, [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION, PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC]); } catch (PDOException \$e) { die("DB Error"); }
function rupiah(\$n) { return 'Rp ' . number_format(\$n, 0, ',', '.'); }
PHPEOF

cat > "$INC_ROOT/auth.php" << 'PHPEOF'
<?php
session_start();
function isUser() { return isset($_SESSION['user_id']); }
function isAdmin() { return isset($_SESSION['admin_id']); }
function requireUser() { if(!isUser()) { header('Location: login.php'); exit; } }
function requireAdmin() { if(!isAdmin()) { header('Location: ../admin/login.php'); exit; } }
PHPEOF

cat > "$INC_ROOT/csrf.php" << 'PHPEOF'
<?php
function generateCsrf() { if(empty($_SESSION['csrf'])) { $_SESSION['csrf'] = bin2hex(random_bytes(32)); } return $_SESSION['csrf']; }
function verifyCsrf($token) { return isset($_SESSION['csrf']) && hash_equals($_SESSION['csrf'], $token); }
PHPEOF

# CSS PREMIUM (MIRIP PING!)
cat > "$WEB_ROOT/assets/style.css" << 'CSSEOF'
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800;900&display=swap');
@import url('https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.5.1/css/all.min.css');
:root{--bg:#09090b;--card:#18181b;--primary:#eab308;--purple:#8b5cf6;--text:#f8fafc;--muted:#a1a1aa;--border:#27272a;}
*{margin:0;padding:0;box-sizing:border-box;font-family:'Inter',sans-serif;}
body{background:var(--bg);color:var(--text);min-height:100vh;display:flex;flex-direction:column;background-image:radial-gradient(circle at 50% 0%, rgba(139,92,246,0.15), transparent 50%);}
a{text-decoration:none;color:inherit;}
.container{max-width:1000px;margin:0 auto;padding:20px;width:100%;}
.navbar{background:rgba(9,9,11,0.8);backdrop-filter:blur(10px);border-bottom:1px solid var(--border);position:sticky;top:0;z-index:100;}
.nav-inner{display:flex;justify-content:space-between;align-items:center;max-width:1000px;margin:0 auto;padding:15px 20px;}
.logo{font-size:1.5em;font-weight:900;color:white;display:flex;align-items:center;gap:10px;letter-spacing:-1px;}
.logo i{color:var(--purple);}
.card{background:var(--card);border:1px solid var(--border);border-radius:20px;padding:25px;margin-bottom:20px;}
.btn{display:inline-block;padding:12px 24px;border-radius:12px;border:none;font-weight:700;cursor:pointer;text-align:center;transition:0.2s;font-size:0.95em;}
.btn-primary{background:var(--primary);color:#000;border-radius:30px;}
.btn-primary:hover{transform:translateY(-2px);box-shadow:0 4px 15px rgba(234,179,8,0.4);}
.btn-purple{background:var(--purple);color:white;border-radius:12px;}
.btn-block{width:100%;display:block;}
.form-group{margin-bottom:15px;}
label{display:block;margin-bottom:8px;color:var(--muted);font-size:0.9em;}
input,select{width:100%;padding:14px 16px;border-radius:12px;border:1px solid var(--border);background:#000;color:var(--text);font-family:inherit;outline:none;}
input:focus{border-color:var(--purple);}
table{width:100%;border-collapse:collapse;margin-top:15px;}
th,td{padding:14px;text-align:left;border-bottom:1px solid var(--border);font-size:0.9em;}
th{color:var(--muted);}
.badge{padding:6px 12px;border-radius:20px;font-size:0.75em;font-weight:700;}
.badge-success{background:rgba(16,185,129,0.15);color:#10b981;}
.badge-pending{background:rgba(234,179,8,0.15);color:#eab308;}

/* HERO SECTION */
.hero{text-align:center;padding:60px 20px;background:linear-gradient(180deg, rgba(139,92,246,0.1) 0%, transparent 100%);}
.hero-pill{display:inline-flex;align-items:center;gap:8px;background:rgba(39,39,42,0.8);padding:8px 16px;border-radius:30px;font-size:0.85em;font-weight:600;margin-bottom:25px;border:1px solid var(--border);}
.dot{width:8px;height:8px;background:#10b981;border-radius:50%;box-shadow:0 0 10px #10b981;}
.hero h1{font-size:3.5em;font-weight:900;line-height:1.1;margin-bottom:20px;letter-spacing:-1px;}
.hero h1 span{color:var(--purple);}
.hero p{color:var(--muted);font-size:1.1em;max-width:600px;margin:0 auto 30px;}
.hero-buttons{display:flex;justify-content:center;gap:15px;flex-wrap:wrap;}

/* DASHBOARD CARD */
.balance-card{background:linear-gradient(135deg, #18181b, #27272a);border:1px solid #3f3f46;border-radius:24px;padding:30px;position:relative;overflow:hidden;}
.balance-card::after{content:'';position:absolute;top:-50px;right:-50px;width:150px;height:150px;background:var(--purple);filter:blur(80px);opacity:0.3;}
.balance-title{color:var(--muted);font-size:0.9em;margin-bottom:5px;}
.balance-amount{font-size:2.8em;font-weight:900;margin-bottom:20px;}
CSSEOF

echo -e "${CYAN}[3/6] Generate Halaman User...${NC}"

cat > "$WEB_ROOT/index.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; if(isUser()) header('Location: dashboard.php'); ?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>RenClouds - Beli Nokos</title><link rel="stylesheet" href="assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="#" class="logo"><i class="fas fa-comment-dots"></i> RenClouds</a><div><a href="login.php" class="btn btn-primary">Masuk</a></div></div></nav>
<div class="hero">
    <div class="hero-pill"><div class="dot"></div> 18.616 OTP masuk sejak September 2026</div>
    <h1>Beli nokos.<br>Tinggal <span>ping!</span></h1>
    <p>Nomor virtual buat terima SMS OTP. Ada nokos WA, Telegram, Shopee, dan layanan lain. Pilih layanan, isi saldo, kodenya muncul begitu SMS masuk.</p>
    <div class="hero-buttons">
        <a href="register.php" class="btn btn-primary" style="padding:15px 30px;font-size:1.1em;">Beli Nomor</a>
        <a href="#harga" class="btn" style="background:#27272a;color:white;padding:15px 30px;font-size:1.1em;border-radius:30px;">Lihat Harga <i class="fas fa-arrow-right"></i></a>
    </div>
</div>
<div class="container" style="text-align:center;margin-top:40px;color:var(--muted);">
    <p><i class="fas fa-check" style="color:#10b981;"></i> Tanpa langganan &nbsp;&nbsp; <i class="fas fa-check" style="color:#10b981;"></i> Isi saldo via QRIS &nbsp;&nbsp; <i class="fas fa-check" style="color:#10b981;"></i> Saldo kembali kalau SMS tak masuk</p>
</div>
</body></html>
PHPEOF

cat > "$WEB_ROOT/register.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; require '../includes/csrf.php';
if ($_SERVER['REQUEST_METHOD']=='POST') {
    if(!verifyCsrf($_POST['csrf'])) die("CSRF Error");
    $u=$_POST['username']; $pw=password_hash($_POST['password'], PASSWORD_DEFAULT);
    $s=$pdo->prepare("SELECT id FROM users WHERE username=?"); $s->execute([$u]);
    if($s->fetch()) { $err="Username sudah terdaftar"; } else {
        $pdo->prepare("INSERT INTO users (username,password) VALUES (?,?)")->execute([$u,$pw]); $success = true;
    }
}
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Daftar</title><link rel="stylesheet" href="assets/style.css"></head><body>
<div class="container" style="max-width:400px;margin-top:50px;"><div class="card">
<h2 style="text-align:center;margin-bottom:20px;">Daftar Akun</h2>
<?php if(isset($err)) echo "<p style='color:red;text-align:center;'>$err</p>"; ?>
<form method="POST"><input type="hidden" name="csrf" value="<?=generateCsrf()?>">
<div class="form-group"><label>Username</label><input type="text" name="username" required></div>
<div class="form-group"><label>Password</label><input type="password" name="password" required></div>
<button class="btn btn-primary btn-block">Daftar</button></form>
<p style="text-align:center;margin-top:15px;font-size:0.9em;">Sudah punya akun? <a href="login.php" style="color:var(--purple)">Masuk</a></p>
</div></div>
</body></html>
PHPEOF

cat > "$WEB_ROOT/login.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; require '../includes/csrf.php';
if ($_SERVER['REQUEST_METHOD']=='POST') {
    if(!verifyCsrf($_POST['csrf'])) die("CSRF Error");
    $s=$pdo->prepare("SELECT * FROM users WHERE username=?"); $s->execute([$_POST['username']]); $u=$s->fetch();
    if($u && password_verify($_POST['password'], $u['password'])) { session_regenerate_id(true); $_SESSION['user_id']=$u['id']; header('Location: dashboard.php'); exit; } else { $err="Username / Password salah"; }
}
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Login</title><link rel="stylesheet" href="assets/style.css"></head><body>
<div class="container" style="max-width:400px;margin-top:50px;"><div class="card">
<h2 style="text-align:center;margin-bottom:20px;">Login User</h2>
<?php if(isset($err)) echo "<p style='color:red;text-align:center;'>$err</p>"; ?>
<form method="POST"><input type="hidden" name="csrf" value="<?=generateCsrf()?>">
<div class="form-group"><label>Username</label><input type="text" name="username" required></div>
<div class="form-group"><label>Password</label><input type="password" name="password" required></div>
<button class="btn btn-primary btn-block">Masuk</button></form>
</div></div></body></html>
PHPEOF

cat > "$WEB_ROOT/dashboard.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; requireUser();
$s=$pdo->prepare("SELECT * FROM users WHERE id=?"); $s->execute([$_SESSION['user_id']]); $u=$s->fetch();
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Dashboard</title><link rel="stylesheet" href="assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="#" class="logo"><i class="fas fa-comment-dots"></i> RenClouds</a><div><a href="profile.php" style="margin-right:15px;color:var(--text);font-size:0.9em;"><i class="fas fa-user"></i> Profil</a><a href="logout.php" style="color:var(--muted);font-size:0.9em;font-weight:600;">Logout</a></div></div></nav>
<div class="container">
<div class="balance-card" style="margin-top:20px;">
    <p class="balance-title">Ruang kamu</p>
    <h3 style="margin-bottom:15px;">Dashboard</h3>
    <p class="balance-title">Total saldo</p>
    <h1 class="balance-amount"><?=rupiah($u['saldo'])?></h1>
    <div style="display:flex;gap:10px;">
        <a href="topup.php" class="btn btn-primary" style="padding:10px 20px;">Isi Saldo</a>
        <a href="buy.php" class="btn btn-purple" style="padding:10px 20px;">Beli Nomor</a>
    </div>
</div>

<h3 style="margin:30px 0 15px;">Menu Cepat</h3>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:15px;">
    <a href="buy.php" class="card" style="text-align:center;padding:20px;margin:0;"><i class="fas fa-mobile-alt" style="font-size:2em;color:var(--purple);margin-bottom:10px;"></i><h4>Beli Nomor</h4></a>
    <a href="transactions.php" class="card" style="text-align:center;padding:20px;margin:0;"><i class="fas fa-history" style="font-size:2em;color:var(--primary);margin-bottom:10px;"></i><h4>Riwayat</h4></a>
</div>
</div></body></html>
PHPEOF

cat > "$WEB_ROOT/buy.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; require '../includes/csrf.php'; requireUser();
$u=$pdo->prepare("SELECT * FROM users WHERE id=?"); $u->execute([$_SESSION['user_id']]); $user=$u->fetch();

if($_SERVER['REQUEST_METHOD']=='POST'){
    if(!verifyCsrf($_POST['csrf'])) die("CSRF Error");
    $service = $_POST['service']; $country = $_POST['country']; $price = 2100;
    if($user['saldo'] < $price) die("<script>alert('Saldo tidak cukup!');window.location='topup.php';</script>");
    
    $pdo->beginTransaction();
    try {
        $new = $user['saldo'] - $price;
        $pdo->prepare("UPDATE users SET saldo=? WHERE id=?")->execute([$new, $user['id']]);
        $pdo->prepare("INSERT INTO orders (user_id, service, country, price, status) VALUES (?,?,?,?, 'active')")->execute([$user['id'], $service, $country, $price]);
        $pdo->commit(); header('Location: transactions.php'); exit;
    } catch(Exception $e) { $pdo->rollBack(); die("Sistem Error"); }
}
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Beli Nomor</title><link rel="stylesheet" href="assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="dashboard.php" class="logo"><i class="fas fa-arrow-left"></i> Kembali</a></div></nav>
<div class="container" style="max-width:500px;">
<div class="card"><h2>Beli Nomor Virtual</h2>
<form method="POST" style="margin-top:20px;"><input type="hidden" name="csrf" value="<?=generateCsrf()?>">
<div class="form-group"><label>Layanan</label>
<select name="service">
<option value="WhatsApp">WhatsApp (Rp 2.100)</option>
<option value="Telegram">Telegram (Rp 1.500)</option>
<option value="Shopee">Shopee (Rp 1.000)</option>
<option value="Gojek">Gojek (Rp 2.500)</option>
</select></div>
<div class="form-group"><label>Negara</label>
<select name="country">
<option value="Indonesia">Indonesia</option>
<option value="Malaysia">Malaysia</option>
<option value="USA">USA</option>
</select></div>
<p style="margin-bottom:15px;color:var(--muted);font-size:0.9em;">Saldo saat ini: <strong><?=rupiah($user['saldo'])?></strong></p>
<button class="btn btn-purple btn-block">Beli Sekarang</button>
</form></div>
</div></body></html>
PHPEOF

# ... (Gua singkat topup, transactions, profile, sama persis kayak v5.0, cuma beda CSS class) ...

cat > "$WEB_ROOT/topup.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; require '../includes/csrf.php'; requireUser();
if($_SERVER['REQUEST_METHOD']=='POST'){
    if(!verifyCsrf($_POST['csrf'])) die("CSRF Error");
    $amt = (int)$_POST['amount']; $proof = '';
    if(isset($_FILES['proof']) && $_FILES['proof']['error']==0){
        $ext = pathinfo($_FILES['proof']['name'], PATHINFO_EXTENSION);
        if(in_array(strtolower($ext), ['jpg','jpeg','png'])){ $proof = 'uploads/payment-proof/'.uniqid().'.'.$ext; move_uploaded_file($_FILES['proof']['tmp_name'], '../../'.$proof); }
    }
    $pdo->prepare("INSERT INTO deposits (user_id, amount, proof_img, status) VALUES (?,?,?,'pending')")->execute([$_SESSION['user_id'], $amt, $proof]);
    header('Location: transactions.php'); exit;
}
$q = $pdo->query("SELECT qris_url FROM settings WHERE id=1")->fetchColumn();
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Top Up</title><link rel="stylesheet" href="assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="dashboard.php" class="logo"><i class="fas fa-arrow-left"></i> Kembali</a></div></nav>
<div class="container" style="max-width:500px;">
<div class="card"><h2 style="margin-bottom:15px;">Isi Saldo (QRIS)</h2>
<img src="<?=$q?>" style="width:100%;max-width:250px;display:block;margin:0 auto 20px;border-radius:10px;background:white;padding:10px;">
<form method="POST" enctype="multipart/form-data"><input type="hidden" name="csrf" value="<?=generateCsrf()?>">
<div class="form-group"><label>Nominal</label><input type="number" name="amount" min="1000" required></div>
<div class="form-group"><label>Bukti TF</label><input type="file" name="proof" required accept="image/*"></div>
<button class="btn btn-primary btn-block">Kirim</button>
</form></div>
</div></body></html>
PHPEOF

cat > "$WEB_ROOT/transactions.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; requireUser();
$s=$pdo->prepare("SELECT * FROM orders WHERE user_id=? ORDER BY id DESC"); $s->execute([$_SESSION['user_id']]); $ord=$s->fetchAll();
$d=$pdo->prepare("SELECT * FROM deposits WHERE user_id=? ORDER BY id DESC"); $d->execute([$_SESSION['user_id']]); $dep=$d->fetchAll();
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Riwayat</title><link rel="stylesheet" href="assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="dashboard.php" class="logo"><i class="fas fa-arrow-left"></i> Kembali</a></div></nav>
<div class="container">
<h2 style="margin-bottom:20px;">Riwayat Pesanan</h2>
<div class="card"><table>
<tr><th>Layanan</th><th>Nomor</th><th>OTP</th><th>Status</th></tr>
<?php foreach($ord as $x): ?>
<tr><td><?=$x['service']?></td><td><?=$x['phone_number'] ?: '-'?></td><td><strong style="color:var(--primary);"><?=$x['otp_code'] ?: '-'?></strong></td><td><span class="badge badge-<?= $x['status']=='completed'?'success':'pending' ?>"><?=strtoupper($x['status'])?></span></td></tr>
<?php endforeach; ?>
</table></div>
<h2 style="margin:30px 0 20px;">Riwayat Top Up</h2>
<div class="card"><table>
<tr><th>Tanggal</th><th>Nominal</th><th>Status</th></tr>
<?php foreach($dep as $x): ?>
<tr><td><?=date('d/m H:i', strtotime($x['created_at']))?></td><td><?=rupiah($x['amount'])?></td><td><span class="badge badge-<?= $x['status']=='approved'?'success':'pending' ?>"><?=strtoupper($x['status'])?></span></td></tr>
<?php endforeach; ?>
</table></div>
</div></body></html>
PHPEOF

echo -e "${CYAN}[4/6] Generate Admin Panel...${NC}"

cat > "$ADMIN_ROOT/login.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; require '../includes/csrf.php';
if ($_SERVER['REQUEST_METHOD']=='POST') {
    if(!verifyCsrf($_POST['csrf'])) die("CSRF Error");
    $s=$pdo->prepare("SELECT * FROM admins WHERE username=?"); $s->execute([$_POST['username']]); $a=$s->fetch();
    if($a && password_verify($_POST['password'], $a['password'])) { session_regenerate_id(true); $_SESSION['admin_id']=$a['id']; header('Location: index.php'); exit; } else { $err="Login gagal"; }
}
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Admin Login</title><link rel="stylesheet" href="../public/assets/style.css"></head><body>
<div class="container" style="max-width:400px;margin-top:100px;"><div class="card" style="border-color:var(--primary);">
<h2 style="text-align:center;margin-bottom:20px;"><i class="fas fa-shield-alt" style="color:var(--primary);"></i> Admin</h2>
<?php if(isset($err)) echo "<p style='color:red;text-align:center;'>$err</p>"; ?>
<form method="POST"><input type="hidden" name="csrf" value="<?=generateCsrf()?>">
<div class="form-group"><label>Username</label><input type="text" name="username" required></div>
<div class="form-group"><label>Password</label><input type="password" name="password" required></div>
<button class="btn btn-primary btn-block">Masuk</button></form>
</div></div></body></html>
PHPEOF

cat > "$ADMIN_ROOT/index.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; requireAdmin();
$tu = $pdo->query("SELECT COUNT(*) FROM users")->fetchColumn();
$tp = $pdo->query("SELECT COUNT(*) FROM deposits WHERE status='pending'")->fetchColumn();
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Admin</title><link rel="stylesheet" href="../public/assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="#" class="logo"><i class="fas fa-shield-alt" style="color:var(--primary);"></i> Admin Panel</a><div><a href="../public/index.php" style="margin-right:15px;font-size:0.9em;">Ke Web</a><a href="logout.php" style="color:var(--muted);font-size:0.9em;">Logout</a></div></div></nav>
<div class="container">
<h2>Overview</h2>
<div style="display:grid;grid-template-columns:1fr 1fr;gap:15px;margin-top:20px;">
<div class="card" style="text-align:center;"><p>Total User</p><h2 style="color:var(--purple);"><?=$tu?></h2></div>
<div class="card" style="text-align:center;"><p>Pending Deposit</p><h2 style="color:var(--primary);"><?=$tp?></h2></div>
</div>
<div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:15px;margin-top:30px;">
<a href="deposits.php" class="card" style="text-align:center;padding:20px;"><i class="fas fa-check-circle" style="font-size:2em;color:var(--purple);margin-bottom:10px;display:block;"></i>Verifikasi</a>
<a href="orders.php" class="card" style="text-align:center;padding:20px;"><i class="fas fa-list" style="font-size:2em;color:var(--purple);margin-bottom:10px;display:block;"></i>Pesanan</a>
<a href="settings.php" class="card" style="text-align:center;padding:20px;"><i class="fas fa-cog" style="font-size:2em;color:var(--purple);margin-bottom:10px;display:block;"></i>Setting API</a>
</div>
</div></body></html>
PHPEOF

cat > "$ADMIN_ROOT/deposits.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; requireAdmin();
if(isset($_GET['action']) && isset($_GET['id'])){
    $id = $_GET['id']; $act = $_GET['action'];
    if($act == 'approve'){
        $pdo->beginTransaction();
        try {
            $d = $pdo->prepare("SELECT * FROM deposits WHERE id=? AND status='pending' FOR UPDATE"); $d->execute([$id]); $dep = $d->fetch();
            if($dep){
                $u = $pdo->prepare("SELECT saldo FROM users WHERE id=? FOR UPDATE"); $u->execute([$dep['user_id']]); $user = $u->fetch();
                $new = $user['saldo'] + $dep['amount'];
                $pdo->prepare("UPDATE users SET saldo=? WHERE id=?")->execute([$new, $dep['user_id']]);
                $pdo->prepare("UPDATE deposits SET status='approved' WHERE id=?")->execute([$id]);
                $pdo->commit();
            }
        } catch(Exception $e) { $pdo->rollBack(); }
        header('Location: deposits.php'); exit;
    } elseif($act == 'reject'){ $pdo->prepare("UPDATE deposits SET status='rejected' WHERE id=?")->execute([$id]); header('Location: deposits.php'); exit; }
}
$d = $pdo->query("SELECT d.*, u.username FROM deposits d JOIN users u ON d.user_id=u.id WHERE d.status='pending'")->fetchAll();
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Deposit</title><link rel="stylesheet" href="../public/assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="index.php" class="logo"><i class="fas fa-arrow-left"></i> Kembali</a></div></nav>
<div class="container">
<h2>Verifikasi Deposit</h2>
<div class="card"><table>
<tr><th>User</th><th>Nominal</th><th>Bukti</th><th>Aksi</th></tr>
<?php foreach($d as $x): ?>
<tr><td><?=htmlspecialchars($x['username'])?></td><td><?=rupiah($x['amount'])?></td><td><a href="../public/<?=$x['proof_img']?>" target="_blank" style="color:var(--purple);">Lihat</a></td>
<td><a href="?action=approve&id=<?=$x['id']?>" class="btn btn-primary" style="padding:6px 12px;font-size:0.8em;">Approve</a> <a href="?action=reject&id=<?=$x['id']?>" class="btn" style="background:red;color:white;padding:6px 12px;font-size:0.8em;">Reject</a></td>
</tr>
<?php endforeach; ?>
</table></div>
</div></body></html>
PHPEOF

cat > "$ADMIN_ROOT/orders.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; requireAdmin();
if(isset($_GET['otp']) && isset($_GET['id'])){
    $pdo->prepare("UPDATE orders SET otp_code=?, status='completed' WHERE id=?")->execute([$_GET['otp'], $_GET['id']]);
    header('Location: orders.php'); exit;
}
$o = $pdo->query("SELECT o.*, u.username FROM orders o JOIN users u ON o.user_id=u.id ORDER BY o.id DESC")->fetchAll();
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Pesanan</title><link rel="stylesheet" href="../public/assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="index.php" class="logo"><i class="fas fa-arrow-left"></i> Kembali</a></div></nav>
<div class="container">
<h2>Pesanan Nokos</h2>
<div class="card"><table>
<tr><th>User</th><th>Layanan</th><th>Status</th><th>OTP</th></tr>
<?php foreach($o as $x): ?>
<tr>
<td><?=htmlspecialchars($x['username'])?></td>
<td><?=$x['service']?></td>
<td><span class="badge badge-<?= $x['status']=='completed'?'success':'pending' ?>"><?=strtoupper($x['status'])?></span></td>
<td>
<?php if($x['status'] == 'active'): ?>
<form method="GET" style="display:flex;gap:5px;">
<input type="hidden" name="id" value="<?=$x['id']?>">
<input type="text" name="otp" placeholder="Kode OTP" style="padding:5px;font-size:0.8em;width:100px;">
<button class="btn btn-primary" style="padding:5px 10px;font-size:0.8em;">Kirim</button>
</form>
<?php else: echo "<strong style='color:var(--primary);'>".$x['otp_code']."</strong>"; endif; ?>
</td>
</tr>
<?php endforeach; ?>
</table></div>
</div></body></html>
PHPEOF

cat > "$ADMIN_ROOT/settings.php" << 'PHPEOF'
<?php require '../includes/config.php'; require '../includes/auth.php'; require '../includes/csrf.php'; requireAdmin();
if($_SERVER['REQUEST_METHOD']=='POST'){
    if(!verifyCsrf($_POST['csrf'])) die("CSRF Error");
    $pdo->prepare("UPDATE settings SET qris_url=?, api_url=?, api_key=? WHERE id=1")->execute([$_POST['qris_url'], $_POST['api_url'], $_POST['api_key']]);
    $ok = "Pengaturan disimpan!";
}
$q = $pdo->query("SELECT * FROM settings WHERE id=1")->fetch();
?>
<!DOCTYPE html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Settings</title><link rel="stylesheet" href="../public/assets/style.css"></head><body>
<nav class="navbar"><div class="nav-inner"><a href="index.php" class="logo"><i class="fas fa-arrow-left"></i> Kembali</a></div></nav>
<div class="container" style="max-width:500px;">
<h2>Pengaturan Sistem</h2>
<div class="card">
<?php if(isset($ok)) echo "<p style='color:green;margin-bottom:10px;'>$ok</p>"; ?>
<form method="POST"><input type="hidden" name="csrf" value="<?=generateCsrf()?>">
<div class="form-group"><label>URL Gambar QRIS</label><input type="url" name="qris_url" value="<?=$q['qris_url']?>" required></div>
<div class="form-group"><label>API Endpoint Nokos</label><input type="text" name="api_url" value="<?=$q['api_url']?>" required></div>
<div class="form-group"><label>API Key</label><input type="text" name="api_key" value="<?=$q['api_key']?>" required></div>
<button class="btn btn-primary btn-block">Simpan</button>
</form>
</div></div></body></html>
PHPEOF

cat > "$ADMIN_ROOT/logout.php" << 'PHPEOF'
<?php session_start(); unset($_SESSION['admin_id']); header('Location: login.php'); exit;
PHPEOF

# NGINX CONFIG
cat > "$NGINX_CONF" << NGINXEOF
server {
    listen 80; listen [::]:80;
    server_name $DOMAIN;
    root /var/www/$DOMAIN/public; index index.php index.html;

    location / { try_files \$uri \$uri/ /index.php?\$query_string; }
    location /admin/ {
        alias /var/www/$DOMAIN/admin/; index index.php;
        try_files \$uri \$uri/ /admin/index.php?\$query_string;
        location ~ \.php\$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/var/run/php/php8.1-fpm.sock; fastcgi_param SCRIPT_FILENAME \$request_filename; }
    }
    location ~ \.php\$ { include snippets/fastcgi-php.conf; fastcgi_pass unix:/var/run/php/php8.1-fpm.sock; }
}
NGINXEOF

ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
chown -R www-data:www-data "/var/www/$DOMAIN"
chmod -R 777 "/var/www/$DOMAIN/uploads"
nginx -t >/dev/null 2>&1 && systemctl reload nginx
systemctl restart php8.1-fpm

clear
echo -e "${GREEN}╔════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅ RENCLOUDS OTP v6.0 BERHASIL!               ║${NC}"
echo -e "${GREEN}║  🎨 UI Mirip Ping! & Admin Panel Mewah         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${CYAN}🔗 User Web:${NC} http://$DOMAIN"
echo -e "${MAGENTA}🔒 Admin Panel (Private):${NC} http://$DOMAIN/admin/login.php"
echo ""
echo -e "${YELLOW}🔑 Kredensial Admin:${NC} admin / Ren11#"
echo ""
echo -e "${YELLOW}💡 Fitur:${NC}"
echo -e "   • Tampilan Depan (Hero, Stats, Tombol Ping!)"
echo -e "   • Dashboard User (Saldo, Beli Nokos)"
echo -e "   • Dashboard Admin (Atur API & QRIS)"
echo -e "   • Sistem OTP (Bisa diinput manual sama Admin)"
echo ""
echo -e "${GREEN}🚀 Silakan buka domain lo!${NC}"
