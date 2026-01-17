# 1. KODE UNTUK MEMBUAT FILE HTML (Otomatis)
$htmlContent = @'
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bel Interaktif Terpusat</title>
    <style>
        body { display: flex; flex-direction: column; justify-content: center; align-items: center; height: 100vh; gap: 20px; background-color: #f0f2f5; font-family: sans-serif; }
        #myIdText { font-size: 18px; background: white; padding: 10px 20px; border-radius: 10px; box-shadow: 0 4px 6px rgba(0,0,0,0.1); border-left: 5px solid #3498db; }
        #statusInfo { font-weight: bold; font-size: 20px; height: 30px; }
        .btn-bel { padding: 30px 60px; font-size: 32px; font-weight: bold; color: white; border: none; border-radius: 15px; cursor: pointer; transition: all 0.1s; box-shadow: 0 8px #2980b9; background-color: #3498db; }
        .btn-bel:active { transform: translateY(4px); box-shadow: 0 4px #1c5980; }
        button:disabled { background-color: #bdc3c7 !important; cursor: not-allowed; box-shadow: none !important; transform: none !important; opacity: 0.6; }
    </style>
</head>
<body>
    <div id="myIdText">Memuat ID...</div>
    <div id="statusInfo">Menghubungkan ke server...</div>
    <button id="btnBiru" class="btn-bel" onclick="handlePress()">BEL BIRU</button>

    <script>
        const SERVER_URL = "http://" + window.location.hostname + ":3000"; 
        const defaultId = 'Player_' + Math.floor(Math.random() * 1000);
        const myId = prompt("Masukkan Username Anda:", defaultId) || defaultId;
        document.getElementById('myIdText').innerText = "User: " + myId;

        async function handlePress() {
            try {
                await fetch(SERVER_URL + "/press?user=" + encodeURIComponent(myId));
                const ctx = new (window.AudioContext || window.webkitAudioContext)();
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();
                osc.type = 'sawtooth'; osc.frequency.setValueAtTime(440, ctx.currentTime);
                gain.gain.setValueAtTime(0.1, ctx.currentTime);
                osc.connect(gain); gain.connect(ctx.destination);
                osc.start(); setTimeout(() => osc.stop(), 1000);
            } catch (e) { console.error("Gagal tekan bel"); }
        }

        setInterval(async () => {
            try {
                const res = await fetch(SERVER_URL + "/status");
                const data = await res.json();
                const btn = document.getElementById('btnBiru');
                const info = document.getElementById('statusInfo');
                if (data.isLocked) {
                    btn.disabled = true;
                    info.innerText = "🔒 DITEKAN OLEH: " + data.lockedBy;
                    info.style.color = "#e74c3c";
                } else {
                    btn.disabled = false;
                    info.innerText = "✅ SIAP!";
                    info.style.color = "#27ae60";
                }
            } catch (e) { document.getElementById('statusInfo').innerText = "⚠️ SERVER OFFLINE"; }
        }, 500);
    </script>
</body>
</html>
'@

$htmlPath = "$PSScriptRoot\index.html"
$htmlContent | Out-File -FilePath $htmlPath -Encoding utf8

# 2. LOGIKA SERVER POWERSHELL
$port = 3000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")

$global:isLocked = $false
$global:lockedBy = ""

Clear-Host
Write-Host "===============================================" -ForegroundColor Cyan
Write-Host "   SERVER BEL INTERAKTIF JALAN!                " -ForegroundColor Cyan
Write-Host "   File HTML dibuat di: $htmlPath              " -ForegroundColor Yellow
Write-Host "   Akses dari browser: http://localhost:$port  " -ForegroundColor White
Write-Host "===============================================" -ForegroundColor Cyan

# Buka file HTML secara otomatis di browser
Start-Process $htmlPath

$listener.Start()

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $res = $context.Response
        $res.AddHeader("Access-Control-Allow-Origin", "*")
        
        $path = $context.Request.Url.LocalPath

        if ($path -eq "/press") {
            if (-not $global:isLocked) {
                $global:isLocked = $true
                $global:lockedBy = $context.Request.QueryString["user"]
                Write-Host "[!] Tombol ditekan oleh: $($global:lockedBy)" -ForegroundColor Yellow
                
                # Reset 10 detik
                $timer = New-Object System.Timers.Timer
                $timer.Interval = 10000
                $timer.AutoReset = $false
                Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
                    $global:isLocked = $false
                    $global:lockedBy = ""
                    Write-Host "[v] Reset: Tombol kembali aktif." -ForegroundColor Green
                } | Out-Null
                $timer.Start()
            }
            $buffer = [System.Text.Encoding]::UTF8.GetBytes("OK")
        } 
        elseif ($path -eq "/status") {
            $json = '{"isLocked": ' + ($global:isLocked.ToString().ToLower()) + ', "lockedBy": "' + $global:lockedBy + '"}'
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $res.ContentType = "application/json"
        }
        else { $buffer = [System.Text.Encoding]::UTF8.GetBytes("Server Active") }

        $res.ContentLength64 = $buffer.Length
        $res.OutputStream.Write($buffer, 0, $buffer.Length)
        $res.Close()
    }
} finally { $listener.Stop() }
