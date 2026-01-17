# --- CONFIGURATION ---
$Port = 12345
$HtmlFile = "$PSScriptRoot\index.html"

# --- 1. MEMBUAT FILE HTML (GABUNGAN HTML, CSS, JS) ---
$HtmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Bel Multiplayer LAN</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; text-align: center; background: #1a1a2e; color: white; padding-top: 50px; }
        .container { max-width: 400px; margin: auto; border: 2px solid #16213e; padding: 20px; border-radius: 15px; background: #0f3460; }
        #user-info { font-size: 1.1em; color: #e94560; margin-bottom: 20px; font-weight: bold; }
        #btnBuzz { 
            width: 200px; height: 200px; border-radius: 50%; border: none;
            background: #e94560; color: white; font-size: 28px; font-weight: bold;
            cursor: pointer; box-shadow: 0 10px #950740; transition: 0.1s;
        }
        #btnBuzz:active { box-shadow: 0 2px #950740; transform: translateY(8px); }
        #btnBuzz:disabled { background: #53354a; box-shadow: none; cursor: not-allowed; opacity: 0.6; }
        #status { margin-top: 30px; font-size: 1.5em; min-height: 40px; color: #f1c40f; }
        .footer { margin-top: 20px; font-size: 0.8em; opacity: 0.5; }
    </style>
</head>
<body>
    <div class="container">
        <div id="user-info">Username: <span id="display-name">...</span></div>
        <button id="btnBuzz" onclick="pressButton()">TEKAN!</button>
        <div id="status">Siap...</div>
        <div class="footer">Menunggu sinyal LAN...</div>
    </div>

    <script>
        // Generate Username Acak
        let randomNum = Math.floor(Math.random() * 900) + 100;
        let defaultName = "Pemain_" + randomNum;
        let username = prompt("Masukkan ID/Username Anda:", defaultName) || defaultName;
        document.getElementById('display-name').innerText = username;

        const btn = document.getElementById('btnBuzz');
        const status = document.getElementById('status');

        function pressButton() {
            // Mengirim perintah ke PowerShell via perubahan judul window (trik Windows 7)
            document.title = "BUZZ:" + username;
        }

        // Fungsi ini dipanggil oleh PowerShell untuk update UI
        function updateStatus(msg, disable) {
            status.innerText = msg;
            btn.disabled = disable;
            if(msg.includes("TEEETTT")) {
                let audio = new Audio('https://www.soundjay.com/buttons/sounds/beep-01a.mp3');
                audio.play();
            }
        }
    </script>
</body>
</html>
"@
$HtmlContent | Out-File -FilePath $HtmlFile -Encoding UTF8

# --- 2. LOGIKA SERVER POWERSHELL ---
Add-Type -AssemblyName System.Windows.Forms
$udp = New-Object System.Net.Sockets.UdpClient($Port)
$endpoint = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, $Port)

# Buka Browser
Start-Process $HtmlFile
Write-Host "Server Bel Aktif di Port $Port. Jangan tutup jendela ini!" -ForegroundColor Green

$Locked = $false
$Winner = ""

while ($true) {
    # 1. Cek jika user menekan tombol di browser (Cek via Window Title)
    $process = Get-Process | Where-Object {$_.MainWindowTitle -like "BUZZ:*"}
    if ($process -and -not $Locked) {
        $Winner = $process.MainWindowTitle.Replace("BUZZ:", "")
        # Broadcast ke semua orang di LAN
        $payload = [System.Text.Encoding]::ASCII.GetBytes("WINNER:$Winner")
        $broadcast = New-Object System.Net.Sockets.UdpClient
        $broadcast.EnableBroadcast = $true
        $dest = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Broadcast, $Port)
        $broadcast.Send($payload, $payload.Length, $dest) | Out-Null
        $broadcast.Close()
        # Reset judul agar tidak terdeteksi dua kali
        $process.MainWindowTitle = "Bel Multiplayer LAN" 
    }

    # 2. Cek kiriman dari LAN
    if ($udp.Available -gt 0) {
        $data = $udp.Receive([ref]$endpoint)
        $msg = [System.Text.Encoding]::ASCII.GetString($data)

        if ($msg -like "WINNER:*" -and -not $Locked) {
            $Locked = $true
            $WinnerName = $msg.Split(":")[1]
            Write-Host "PEMENANG: $WinnerName" -ForegroundColor Yellow
            
            # Update UI via script (Simulasi interaksi browser)
            # Karena Windows 7 terbatas, user cukup melihat status di layar
            # Kita gunakan pesan sistem atau instruksi di console
            
            Start-Sleep -Seconds 10
            $Locked = $false
            Write-Host "Bel Kembali Aktif!" -ForegroundColor Cyan
        }
    }
    Start-Sleep -Milliseconds 100
}
