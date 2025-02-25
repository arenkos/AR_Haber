<?php
	session_start();
	if(isset($_SESSION['user'])){
		$user = $_SESSION['user'];
	}else{
		$_SESSION['user'] = session_id();
		$user = $_SESSION['user'];
	}
	
	$haber_url = $_GET['haber_url'];
	$arama = $_GET['arama'];
	
	$servername = "localhost:3306";
	$username = "aren";
	$password = "Arenkos1.";
	$database = "haber";
	
	$connection = mysqli_connect($servername, $username, $password, $database);

	// Bağlantıyı kontrol et
	if (!$connection) {
		die("Bağlantı hatası: " . mysqli_connect_error());
	}
?>
<script>
	function arama(aranan){
		document.getElementById('aramaSonuclari').style.display = 'flex'; 
		var xhr = new XMLHttpRequest();
		xhr.open('GET', 'arama.php?arama='+aranan, true);
		xhr.send();
	}
	function like(haber_url){
		document.getElementById('like').style.display = 'none'; 
		document.getElementById('liked').style.display = 'flex'; 
		document.getElementById('dislike').style.display = 'flex';
		document.getElementById('disliked').style.display = 'none';
		document.getElementById('div').style.display = 'flex';
		var xhr = new XMLHttpRequest();
		xhr.open('GET', 'like.php?haber_url='+haber_url, true);
		xhr.send();
	}
	function dislike(haber_url){
		document.getElementById('dislike').style.display = 'none'; 
		document.getElementById('disliked').style.display = 'flex'; 
		document.getElementById('like').style.display = 'flex';
		document.getElementById('liked').style.display = 'none';
		var xhr = new XMLHttpRequest();
		xhr.open('GET', 'dislike.php?haber_url='+haber_url, true);
		xhr.send();
	}
	function unlike(haber_url){
		document.getElementById('liked').style.display = 'none'; 
		document.getElementById('like').style.display = 'flex'; 
		var xhr = new XMLHttpRequest();
		xhr.open('GET', 'unlike.php?haber_url='+haber_url, true);
		xhr.send();
	}
	function undislike(haber_url){
		document.getElementById('disliked').style.display = 'none'; 
		document.getElementById('dislike').style.display = 'flex'; 
		var xhr = new XMLHttpRequest();
		xhr.open('GET', 'undislike.php?haber_url='+haber_url, true);
		xhr.send();
	}
	function yorumlar(){
		document.getElementById('resim').style.display = 'none'; 
		document.getElementById('baslik').style.display = 'none'; 
		document.getElementById('haber').style.display = 'none'; 
		document.getElementById('x').style.display = 'flex'; 
	}
	function haber(){
		document.getElementById('resim').style.display = 'none'; 
		document.getElementById('baslik').style.display = 'none'; 
		document.getElementById('yorumlar').style.display = 'none'; 
		document.getElementById('x').style.display = 'none';
		document.getElementById('x').style.textAlign = 'right';
		document.getElementById('x').style.display = 'block';
		document.getElementById('haber').style.display = 'flex'; 
	}
	function kapat(){
		document.getElementById('resim').style.display = 'flex'; 
		document.getElementById('baslik').style.display = 'flex'; 
		document.getElementById('yorumlar').style.display = 'none'; 
		document.getElementById('x').style.display = 'none';
		document.getElementById('x').style.textAlign = 'right';
		document.getElementById('x').style.display = 'block';
		document.getElementById('haber').style.display = 'none'; 
	}
	function arama() {
		var aramaKelimesi = document.getElementById('aramaKutusu').value;

		if (aramaKelimesi.trim() !== '') {
			$.ajax({
				type: 'POST',
				url: 'arama_haber.php', // Sunucu tarafındaki PHP dosyanızın adı
				data: { kelime: aramaKelimesi },
				success: function(response) {
					$('#aramaSonuclari').html(response);
				}
			});
		} else {
			$('#aramaSonuclari').html('');
		}
	}
</script>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0 auto;background-color:black;">
<input type="text" id="aramaKutusu" oninput="arama(this.value)" placeholder="Arama..." style="display:block;height:15px;width:100vw;max-width:70vh;">
<div id="aramaSonuclari" style="height:auto;width:100vw;max-width:70vh;margin:0 auto;display:flex;">
	<?php
		$sql = "SELECT * FROM haberler WHERE baslik LIKE '%$arama%' OR kaynak LIKE '%$arama%' OR kategori LIKE '%$arama%' ORDER BY tarih DESC LIMIT 10";
		mysqli_set_charset($connection, "utf8");
		$result = mysqli_query($connection, $sql);
		if (mysqli_num_rows($result) > 0) {
			while ($row = mysqli_fetch_assoc($result)) { 
				$baslik = $row['baslik'];
				$haber_url = $row['haber_url'];
				$resim_url = $row['resim_url'];
				$kaynak = $row['kaynak'];
			?>
				<div style="height:100vh;width:100vw;max-width:70vh;max-width:70vh;margin:0 auto;">
					<h3 style="height:5vh;width:100vw;max-width:70vh;margin:0 center;color:white;"><?php echo $kaynak; ?></h3>
					<p onclick="kapat()" style="margin:0;text-align:right;width:100%;height:auto;color:white;display:none;" id="x">X</p>
					<img id="resim" onclick="haber()" ondblclick="like()" style="display:flex;height:70vh;width:100vw;max-width:70vh;margin:0 auto;" src="<?php echo $resim_url; ?>">
					<p id="baslik" onclick="haber()" style="display:flex;height:auto;width:100vw;max-width:70vh;margin:0 auto;"><?php echo $baslik; ?></p>
					<iframe id="haber" src="https://www.medyabosshaber.com" style="height:70vh;width:100vw;max-width:70vh;display:none;"></iframe>
					<iframe id="yorumlar" src="yorumlar.php?haber_url=<?php echo $haber_url; ?>" style="display:none;height:70vh;width:100vw;max-width:70vh;margin:0 auto;text-align:center;"></iframe>
					<div id="div" style="height:5vh;width:100vw;max-width:70vh;margin:0 auto;text-align:center;">
						<table style="height:100%;width:30vh;margin:0 auto;text-align:center;">
							<tr style="height:100%;width:100%;margin:0 auto;text-align:center;">
								<td style="height:5vh;width:5vh;margin:0 auto;text-align:center;">
									<img id="like" src="like.png" onclick="like(<?php echo $haber_url; ?>)" style="width:5vh;height:5vh;display:flex;margin:0 auto;text-align:center;margin:0 auto;text-align:center;margin:0 auto;text-align:center;"margin:0 auto;text-align:center;>
									<img id="liked" src="liked.png" onclick="unlike(<?php echo $haber_url; ?>)" style="width:5vh;height:5vh;display:none;margin:0 auto;text-align:center;margin:0 auto;text-align:center;"margin:0 auto;text-align:center;>
								</td>
								<td style="height:5vh;width:5vh;margin:0 auto;text-align:center;">
									<img id="dislike" src="dislike.png" onclick="dislike(<?php echo $haber_url; ?>)" style="width:5vh;height:5vh;display:flex;margin:0 auto;text-align:center;"margin:0 auto;text-align:center;>
									<img id="disliked" src="disliked.png" onclick="undislike(<?php echo $haber_url; ?>)" style="width:5vh;height:5vh;display:none;margin:0 auto;text-align:center;">
								</td>
								<td style="height:5vh;width:5vh;margin:0 auto;text-align:center;">
									<img id="yorum" src="yorum.png" onclick="yorumlar()" style="width:5vh;height:5vh;display:flex;margin:0 auto;text-align:center;">
								</td>
							</tr>
						</table>
					</div>
				</div>
			<?php }
		} ?>
</div>
</body>
</html>
