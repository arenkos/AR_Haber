<?php
/**
 * Abonelik Durumu Kontrol
 * armedia.live/check_subscription.php
 * 
 * Kullanıcının aktif aboneliğini veritabanından kontrol eder
 */

header('Content-Type: application/json; charset=utf-8');

// Veritabanı bağlantısı
$host = 'localhost';
$dbname = 'YOUR_DATABASE';
$username_db = 'YOUR_USERNAME';
$password = 'YOUR_PASSWORD';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username_db, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    echo json_encode(['success' => false, 'error' => 'Veritabanı bağlantı hatası']);
    exit;
}

// GET veya POST parametrelerini al
$userId = $_GET['username'] ?? $_POST['username'] ?? null;

if (!$userId) {
    echo json_encode(['success' => false, 'error' => 'Kullanıcı adı gerekli']);
    exit;
}

try {
    $stmt = $pdo->prepare("
        SELECT abonelik, abonelik_bitis, transaction_id 
        FROM users 
        WHERE username = ?
    ");
    $stmt->execute([$userId]);
    $user = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$user) {
        echo json_encode(['success' => false, 'error' => 'Kullanıcı bulunamadı']);
        exit;
    }

    $subscriptionType = $user['abonelik'];
    $expiresDate = $user['abonelik_bitis'];

    // Abonelik var mı ve süresi geçmemiş mi kontrol et
    $isActive = false;
    if ($subscriptionType && $expiresDate) {
        $expiresTimestamp = strtotime($expiresDate);
        $isActive = $expiresTimestamp > time();

        // Süresi geçmişse veritabanını temizle
        if (!$isActive) {
            $updateStmt = $pdo->prepare("
                UPDATE users 
                SET abonelik = NULL, abonelik_bitis = NULL 
                WHERE username = ?
            ");
            $updateStmt->execute([$userId]);
            $subscriptionType = null;
            $expiresDate = null;
        }
    }

    echo json_encode([
        'success' => true,
        'is_active' => $isActive,
        'subscription_type' => $subscriptionType,
        'expires_date' => $expiresDate,
        'has_ad_free' => in_array($subscriptionType, ['adfree', 'premium']),
        'has_ai_access' => in_array($subscriptionType, ['ai', 'premium']),
        'has_premium' => $subscriptionType === 'premium'
    ]);

} catch (PDOException $e) {
    echo json_encode(['success' => false, 'error' => 'Veritabanı hatası: ' . $e->getMessage()]);
}
?>