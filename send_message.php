<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');
include 'db.php';
$conn = $connection;

// Önce POST, sonra GET verilerini alıyoruz
$data = json_decode(file_get_contents("php://input"), true);

// Eğer POST verisi varsa, POST verilerini kullan
if (!$data) {
    // POST verisi yoksa GET ile verileri al
    $data = $_GET;
}

if (isset($data['sender_id'], $data['receiver_id'], $data['text'])) {
    $sender_id = $data['sender_id'];
    $receiver_id = $data['receiver_id'];
    $text = $data['text'];
    $deviceTokens = $data['device_token'] ?? ''; // Virgülle ayrılmış token'lar olabilir
    $isProduction = $data['is_production'] ?? false; // Production ortamı mı?

    // Haber bilgileri (opsiyonel)
    $haber_baslik = $data['haber_baslik'] ?? null;
    $haber_resim = $data['haber_resim'] ?? null;

    // Mesajı veritabanına ekle (haber bilgileri dahil)
    $sql = "INSERT INTO mesajlar (sender_id, receiver_id, text, haber_baslik, haber_resim) VALUES (?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        echo json_encode(["success" => false, "status" => "error", "error" => "SQL hazırlama hatası: " . $conn->error]);
        $conn->close();
        exit;
    }

    $stmt->bind_param("sssss", $sender_id, $receiver_id, $text, $haber_baslik, $haber_resim);

    $response = $stmt->execute();

    $result = [];

    if ($response) {
        $result["success"] = true;
        $result["status"] = "success";

        // Eğer deviceToken varsa bildirim gönder
        if (!empty($deviceTokens)) {
            // Token'ları virgülle ayır
            $tokens = explode(',', $deviceTokens);
            $notificationResults = [];

            foreach ($tokens as $token) {
                $token = trim($token); // Boşlukları temizle

                // Boş, "test", web_ ile başlayan veya UUID formatındaki token'ları atla
                if (empty($token) || $token === 'test' || strpos($token, 'web_') === 0 || preg_match('/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i', $token)) {
                    continue;
                }

                // Token tipini belirle ve uygun bildirim gönder
                if (isApnsToken($token)) {
                    // iOS APNs token
                    $notificationResponse = sendApnsPushNotification($token, $text, $sender_id, $isProduction);
                    $notificationResults[] = json_decode($notificationResponse, true);
                } else if (isFcmToken($token)) {
                    // Android FCM token
                    $notificationResponse = sendFcmPushNotification($token, $text, $sender_id);
                    $notificationResults[] = json_decode($notificationResponse, true);
                }
            }

            if (!empty($notificationResults)) {
                $result["notifications"] = $notificationResults;
            }
        }
    } else {
        $result["success"] = false;
        $result["status"] = "error";
        $result["error"] = "Veritabanı hatası: " . $stmt->error;
    }

    echo json_encode($result);
    $stmt->close();
} else {
    echo json_encode(["success" => false, "status" => "error", "error" => "Missing required parameters: sender_id, receiver_id, text"]);
}

$conn->close();

// Token tipini belirle - iOS APNs (64 karakter hex)
function isApnsToken($token)
{
    return strlen($token) == 64 && ctype_xdigit($token);
}

// Token tipini belirle - Android FCM (~152+ karakter)
function isFcmToken($token)
{
    return strlen($token) > 100 && !ctype_xdigit($token);
}

// iOS APNs Push Notification
function sendApnsPushNotification($deviceToken, $message, $senderId, $isProduction = false)
{
    // Ortama göre APNS URL'sini belirle
    if ($isProduction) {
        $apnsUrl = "https://api.push.apple.com/3/device/" . $deviceToken;
    } else {
        $apnsUrl = "https://api.sandbox.push.apple.com/3/device/" . $deviceToken;
    }

    $keyFilePath = "AuthKey_U2SQ7V9535.p8";
    $keyId = "U2SQ7V9535";
    $teamId = "5XW7Z342Y8";
    $bundleId = "AR-Software-Consultancy.AR-Haber";

    $privateKey = openssl_pkey_get_private("file://" . $keyFilePath);
    if (!$privateKey) {
        return json_encode(["status" => "error", "platform" => "ios", "message" => "P8 anahtarı yüklenemedi."]);
    }

    $header = json_encode(['alg' => 'ES256', 'kid' => $keyId]);
    $claims = json_encode(['iss' => $teamId, 'iat' => time()]);

    $headerEncoded = base64UrlEncode($header);
    $claimsEncoded = base64UrlEncode($claims);

    $signature = "";
    openssl_sign($headerEncoded . "." . $claimsEncoded, $signature, $privateKey, OPENSSL_ALGO_SHA256);
    $jwt = $headerEncoded . "." . $claimsEncoded . "." . base64UrlEncode($signature);

    $payload = [
        'aps' => [
            'alert' => [
                'title' => "Yeni Mesaj",
                'body' => "$senderId: $message"
            ],
            'sound' => 'default',
            'category' => 'CHAT_MESSAGE'
        ],
        'user_id' => $senderId
    ];

    $jsonPayload = json_encode($payload);

    $ch = curl_init($apnsUrl);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "authorization: bearer $jwt",
        "apns-topic: $bundleId",
        "content-type: application/json"
    ]);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, $jsonPayload);
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_2_0);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    $result = [];
    if ($response === false) {
        $result = ["status" => "error", "platform" => "ios", "message" => curl_error($ch)];
    } else {
        if ($httpCode == 200) {
            $result = ["status" => "success", "platform" => "ios", "message" => "Bildirim başarıyla gönderildi."];
        } else {
            $result = ["status" => "error", "platform" => "ios", "message" => "Bildirim başarısız. HTTP Kod: $httpCode", "response" => $response];
        }
    }

    curl_close($ch);
    return json_encode($result);
}

// Android FCM HTTP v1 API Push Notification
function sendFcmPushNotification($deviceToken, $message, $senderId)
{
    $serviceAccountPath = "ar-haber-firebase-adminsdk-fbsvc-d6a3e98abc.json";
    $projectId = "ar-haber";

    // Service Account dosyasını oku
    $serviceAccountJson = file_get_contents($serviceAccountPath);
    if (!$serviceAccountJson) {
        return json_encode(["status" => "error", "platform" => "android", "message" => "Service Account dosyası okunamadı."]);
    }

    $serviceAccount = json_decode($serviceAccountJson, true);

    // OAuth2 Access Token al
    $accessToken = getFcmAccessToken($serviceAccount);
    if (!$accessToken) {
        return json_encode(["status" => "error", "platform" => "android", "message" => "Access token alınamadı."]);
    }

    // FCM v1 API URL
    $fcmUrl = "https://fcm.googleapis.com/v1/projects/{$projectId}/messages:send";

    // FCM mesaj payload
    $fcmPayload = [
        "message" => [
            "token" => $deviceToken,
            "notification" => [
                "title" => "Yeni Mesaj",
                "body" => "$senderId: $message"
            ],
            "data" => [
                "type" => "chat",
                "sender_id" => $senderId,
                "message" => $message
            ],
            "android" => [
                "priority" => "high",
                "notification" => [
                    "channel_id" => "ar_haber_notifications",
                    "sound" => "default"
                ]
            ]
        ]
    ];

    $ch = curl_init($fcmUrl);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        "Authorization: Bearer $accessToken",
        "Content-Type: application/json"
    ]);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($fcmPayload));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);

    $response = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);

    $result = [];
    if ($response === false) {
        $result = ["status" => "error", "platform" => "android", "message" => curl_error($ch)];
    } else {
        if ($httpCode == 200) {
            $result = ["status" => "success", "platform" => "android", "message" => "FCM bildirimi başarıyla gönderildi."];
        } else {
            $result = ["status" => "error", "platform" => "android", "message" => "FCM bildirimi başarısız. HTTP Kod: $httpCode", "response" => $response];
        }
    }

    curl_close($ch);
    return json_encode($result);
}

// FCM için OAuth2 Access Token al
function getFcmAccessToken($serviceAccount)
{
    $tokenUri = $serviceAccount['token_uri'];
    $clientEmail = $serviceAccount['client_email'];
    $privateKey = $serviceAccount['private_key'];

    // JWT oluştur
    $now = time();
    $header = base64UrlEncode(json_encode(['alg' => 'RS256', 'typ' => 'JWT']));
    $claims = base64UrlEncode(json_encode([
        'iss' => $clientEmail,
        'scope' => 'https://www.googleapis.com/auth/firebase.messaging',
        'aud' => $tokenUri,
        'iat' => $now,
        'exp' => $now + 3600
    ]));

    $signature = '';
    $key = openssl_pkey_get_private($privateKey);
    if (!$key) {
        return null;
    }

    openssl_sign($header . '.' . $claims, $signature, $key, OPENSSL_ALGO_SHA256);
    $jwt = $header . '.' . $claims . '.' . base64UrlEncode($signature);

    // Token isteği
    $ch = curl_init($tokenUri);
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_POSTFIELDS, http_build_query([
        'grant_type' => 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion' => $jwt
    ]));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, ['Content-Type: application/x-www-form-urlencoded']);

    $response = curl_exec($ch);
    curl_close($ch);

    if ($response) {
        $tokenData = json_decode($response, true);
        return $tokenData['access_token'] ?? null;
    }

    return null;
}

// Base64 URL encode
function base64UrlEncode($data)
{
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}
?>