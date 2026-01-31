<?php
/**
 * Apple Receipt Validation & Subscription Management
 * armedia.live/validate_receipt.php
 * 
 * Bu script:
 * 1. iOS'tan gelen receipt'i Apple'a gönderir
 * 2. Doğrulama başarılıysa veritabanına kaydeder
 * 3. Abonelik durumunu günceller
 */

header('Content-Type: application/json; charset=utf-8');

// Veritabanı bağlantısı
$host = 'localhost';
$dbname = 'YOUR_DATABASE';
$username = 'YOUR_USERNAME';
$password = 'YOUR_PASSWORD';

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
} catch (PDOException $e) {
    echo json_encode(['success' => false, 'error' => 'Veritabanı bağlantı hatası']);
    exit;
}

// POST verilerini al
$input = json_decode(file_get_contents('php://input'), true);

$receiptData = $input['receipt_data'] ?? null;
$userId = $input['username'] ?? null;
$productId = $input['product_id'] ?? null;

if (!$receiptData || !$userId) {
    echo json_encode(['success' => false, 'error' => 'Eksik parametreler']);
    exit;
}

// Apple App Store Shared Secret (App Store Connect'ten alınır)
$sharedSecret = 'YOUR_SHARED_SECRET';

// Apple Doğrulama URL'leri
$sandboxUrl = 'https://sandbox.itunes.apple.com/verifyReceipt';
$productionUrl = 'https://buy.itunes.apple.com/verifyReceipt';

/**
 * Apple'a receipt gönder ve doğrula
 */
function verifyReceiptWithApple($receiptData, $sharedSecret, $url) {
    $postData = json_encode([
        'receipt-data' => $receiptData,
        'password' => $sharedSecret,
        'exclude-old-transactions' => true
    ]);
    
    $ch = curl_init($url);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $postData);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/json']);
    curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 30);
    
    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    
    if ($httpCode !== 200) {
        return null;
    }
    
    return json_decode($response, true);
}

// Önce production'da dene
$appleResponse = verifyReceiptWithApple($receiptData, $sharedSecret, $productionUrl);

// Status 21007 ise sandbox'ta dene (test ortamı)
if ($appleResponse && $appleResponse['status'] == 21007) {
    $appleResponse = verifyReceiptWithApple($receiptData, $sharedSecret, $sandboxUrl);
}

// Doğrulama başarısız
if (!$appleResponse || $appleResponse['status'] != 0) {
    $statusMessages = [
        21000 => 'App Store isteği okunamadı',
        21002 => 'Receipt verisi hatalı',
        21003 => 'Receipt doğrulanamadı',
        21004 => 'Shared secret eşleşmiyor',
        21005 => 'Receipt sunucusu geçici olarak kullanılamıyor',
        21006 => 'Geçerli abonelik bulunamadı',
        21007 => 'Sandbox receipt, production ortamında kullanıldı',
        21008 => 'Production receipt, sandbox ortamında kullanıldı',
        21010 => 'Hesap bulunamadı veya silindi'
    ];
    
    $errorMsg = $statusMessages[$appleResponse['status'] ?? 0] ?? 'Bilinmeyen hata';
    echo json_encode(['success' => false, 'error' => $errorMsg, 'status' => $appleResponse['status'] ?? -1]);
    exit;
}

// Aktif abonelik bilgilerini al
$latestReceiptInfo = $appleResponse['latest_receipt_info'] ?? [];
$pendingRenewalInfo = $appleResponse['pending_renewal_info'] ?? [];

if (empty($latestReceiptInfo)) {
    echo json_encode(['success' => false, 'error' => 'Abonelik bilgisi bulunamadı']);
    exit;
}

// En son aktif aboneliği bul
$activeSubscription = null;
$now = time() * 1000; // Apple milisaniye kullanıyor

foreach ($latestReceiptInfo as $receipt) {
    $expiresDate = (int)($receipt['expires_date_ms'] ?? 0);
    
    if ($expiresDate > $now) {
        // Aktif abonelik
        if (!$activeSubscription || $expiresDate > (int)($activeSubscription['expires_date_ms'] ?? 0)) {
            $activeSubscription = $receipt;
        }
    }
}

if (!$activeSubscription) {
    // Abonelik süresi dolmuş, veritabanını güncelle
    $stmt = $pdo->prepare("UPDATE users SET abonelik = NULL, abonelik_bitis = NULL WHERE username = ?");
    $stmt->execute([$userId]);
    
    echo json_encode([
        'success' => true,
        'is_active' => false,
        'message' => 'Abonelik süresi dolmuş'
    ]);
    exit;
}

// Abonelik bilgilerini çıkar
$subscriptionProductId = $activeSubscription['product_id'];
$transactionId = $activeSubscription['transaction_id'];
$originalTransactionId = $activeSubscription['original_transaction_id'];
$purchaseDate = date('Y-m-d H:i:s', (int)($activeSubscription['purchase_date_ms'] ?? 0) / 1000);
$expiresDate = date('Y-m-d H:i:s', (int)($activeSubscription['expires_date_ms'] ?? 0) / 1000);

// Abonelik tipini belirle
$subscriptionType = null;
switch ($subscriptionProductId) {
    case 'com.arhaber.subscription.adfree':
        $subscriptionType = 'adfree';
        break;
    case 'com.arhaber.subscription.ai':
        $subscriptionType = 'ai';
        break;
    case 'com.arhaber.subscription.premium':
        $subscriptionType = 'premium';
        break;
}

// Veritabanına kaydet/güncelle
try {
    $stmt = $pdo->prepare("
        UPDATE users 
        SET abonelik = ?, 
            abonelik_bitis = ?,
            transaction_id = ?,
            original_transaction_id = ?
        WHERE username = ?
    ");
    $stmt->execute([
        $subscriptionType,
        $expiresDate,
        $transactionId,
        $originalTransactionId,
        $userId
    ]);
    
    echo json_encode([
        'success' => true,
        'is_active' => true,
        'subscription_type' => $subscriptionType,
        'expires_date' => $expiresDate,
        'product_id' => $subscriptionProductId
    ]);
    
} catch (PDOException $e) {
    echo json_encode(['success' => false, 'error' => 'Veritabanı güncelleme hatası: ' . $e->getMessage()]);
}
?>
