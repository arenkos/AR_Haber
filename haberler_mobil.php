<?php
header('Content-Type: application/json; charset=utf-8');

session_start();
if (isset($_SESSION['user'])) {
    $user = $_SESSION['user'];
} else {
    $_SESSION['user'] = session_id();
    $user = $_SESSION['user'];
}

// Database connection
include_once 'db.php';

if (!$connection) {
    http_response_code(500); // Internal Server Error
    echo json_encode(['error' => 'Database connection failed: ' . mysqli_connect_error()]);
    exit;
}

mysqli_set_charset($connection, "utf8mb4");

$carpan = isset($_GET['carpan']) ? (int) $_GET['carpan'] : 0;
$arama = isset($_GET['arama']) ? mysqli_real_escape_string($connection, trim($_GET['arama'])) : '';
$kaynak = isset($_GET['kaynak']) ? mysqli_real_escape_string($connection, trim($_GET['kaynak'])) : '';
$kategori = isset($_GET['kategori']) ? mysqli_real_escape_string($connection, trim($_GET['kategori'])) : '';

// Build the SQL query
$sql = "SELECT * FROM haberler WHERE resim_url != ''";

// Filter by search term
if (!empty($arama)) {
    $sql .= " AND (baslik LIKE '%$arama%' OR kaynak LIKE '%$arama%' OR kategori LIKE '%$arama%')";
}

// Filter by source (kaynak) - virgülle ayrılmış çoklu kaynak destekli
// Türkçe karaktersiz versiyonları da kabul et
if (!empty($kaynak)) {
    $kaynaklar = explode(',', $kaynak);
    $kaynaklar_normalized = [];

    foreach ($kaynaklar as $k) {
        $k_trimmed = trim($k);
        // Türkçe karaktersiz versiyonları Türkçe karakterli versiyonlara dönüştür
        $k_normalized = str_replace(
            ['TURK', 'TURKIYE', 'SOZCU', 'HABERTÜRK', 'HABERTURK'],
            ['TÜRK', 'TÜRKİYE', 'SÖZCÜ', 'HABERTÜRK', 'HABERTÜRK'],
            $k_trimmed
        );
        $kaynaklar_normalized[] = "'" . mysqli_real_escape_string($connection, $k_normalized) . "'";
    }

    $sql .= " AND kaynak IN (" . implode(',', $kaynaklar_normalized) . ")";
}

// Filter by category (kategori) - virgülle ayrılmış çoklu kategori destekli
// Türkçe karaktersiz versiyonları da kabul et
if (!empty($kategori)) {
    $kategoriler = explode(',', $kategori);
    $kategoriler_normalized = [];

    foreach ($kategoriler as $k) {
        $k_trimmed = trim($k);
        // Türkçe karaktersiz versiyonları Türkçe karakterli versiyonlara dönüştür
        $k_normalized = str_replace(
            ['Dunya', 'Gundem', 'Saglik'],
            ['Dünya', 'Gündem', 'Sağlık'],
            $k_trimmed
        );
        $kategoriler_normalized[] = "'" . mysqli_real_escape_string($connection, $k_normalized) . "'";
    }

    $sql .= " AND kategori IN (" . implode(',', $kategoriler_normalized) . ")";
}

$sql .= " ORDER BY tarih DESC, id DESC LIMIT " . ($carpan * 10) . ", 10";

// Execute the query
$result = mysqli_query($connection, $sql);

if (!$result) {
    http_response_code(500); // Internal Server Error
    echo json_encode(['error' => 'Database query failed: ' . mysqli_error($connection)]);
    mysqli_close($connection);
    exit;
}

$news = [];
while ($row = mysqli_fetch_assoc($result)) {
    $news[] = [
        'id' => (int) $row['id'],
        'baslik' => $row['baslik'],
        'tarih' => $row['tarih'],
        'kaynak' => $row['kaynak'],
        'kategori' => $row['kategori'],
        'resim_url' => $row['resim_url'],
        'haber_url' => $row['haber_url']
    ];
}

// Output results
if (empty($news)) {
    http_response_code(404); // Not Found
    echo json_encode(['message' => 'No data found'], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
} else {
    echo json_encode($news, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
}

mysqli_close($connection);
?>