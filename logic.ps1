# --- CONFIG SERVER ---
$port = 3000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")

# Variabel Penyimpan (Hanya ID dan Status)
$global:status = "false"
$global:user = ""

# --- KONTEN HTML ---
$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Bel Cepat Tepat</title>
    <style>
        body { display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #ecf0f1; font-family: sans-serif; }
        .bel { padding: 60px 100px; font-size: 50px; font-weight: bold; cursor: pointer; background: #2980b9; color: white; border: none; border-radius: 25px; box-shadow: 0 12px #1c5980; transition: 0.1s; }
        .bel:active { transform: translateY(4px); box-shadow: 0 8px #1c5980; }
        .bel:disabled { background: #95a5a6 !important; box-shadow: none; transform: translateY(8px); cursor: not-allowed; }
        #info { font-size: 30px; margin-bottom: 30px; font-weight: bold; color: #2c3e50; }
        .reset { margin-top: 60px; padding: 15px 30px; background: #e74c3c; color: white; border: none; border-radius: 8px; cursor: pointer; font-weight: bold; }
    </style>
</head>
<body>
    <div id="info">Menghubungkan...</div>
    <button id="btn" class="bel" onclick="pencet()">BEL</button>
    <button class="reset" onclick="reset()">RESET ULANG</button>

    <script>
        // Prompt ID Unik
        const idDefault = 'Pemain_' + Math.floor(1000 + Math.random() * 9000);
        const myId = prompt("Masukkan Nama Anda:", idDefault) || idDefault;
        
        const btn = document.getElementById('btn');
        const info = document.getElementById('info');

        // Fungsi Suara Beep
        function bunyi() {
            try {
                const ctx = new (window.AudioContext || window.webkitAudioContext)();
                const osc = ctx.createOscillator();
                osc.type = 'sawtooth';
                osc.connect(ctx.destination);
                osc.start(); setTimeout(() => osc.stop(), 600);
            } catch(e){}
        }

        // Kirim perintah ke server
        async function pencet() {
            bunyi();
            btn.disabled = true; 
            // Mencoba mengunci server dengan nama kita
            await fetch('/update?lock=true&user=' + encodeURIComponent(myId));
        }

        // Fungsi Reset
        async function reset() {
            await fetch('/update?lock=false&user=');
        }

        // Polling 5ms (Sangat Akurat)
        setInterval(async () => {
            try {
                const res = await fetch('/data');
                const data = await res.json();
                
                if (data.isLocked === "true") {
                    btn.disabled = true;
                    info.innerText = "PEMENANG: " + data.user;
                    info.style.color = "#c0392b";
                } else {
                    btn.disabled = false;
                    info.innerText = "SIAP... TEKAN!";
                    info.style.color = "#27ae60";
                }
            } catch (e) {}
        }, 5);
    </script>
</body>
</html>
"@

# --- JALANKAN SERVER ---
Clear-Host
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host " SERVER BEL AKTIF (Windows 7 Mode)     " -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "Buka: http://localhost:3000" -ForegroundColor White
Write-Host "Tekan Ctrl+C untuk mematikan server." -ForegroundColor Red

$listener.Start()

try {
    while ($listener.IsListening) {
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $res = $ctx.Response
        $res.AddHeader("Access-Control-Allow-Origin", "*")
        $path = $req.Url.LocalPath

        if ($path -eq "/update") {
            $newLock = $req.QueryString["lock"]
            $newUser = $req.QueryString["user"]

            # LOGIKA UTAMA: Hanya terima jika server sedang kosong (false)
            # ATAU jika ini perintah reset (false)
            if ($global:status -eq "false" -or $newLock -eq "false") {
                $global:status = $newLock
                $global:user = $newUser
                Write-Host "Status Terkunci Oleh: $global:user" -ForegroundColor Green
            } else {
                Write-Host "Ditolak: $newUser (Terlambat)" -ForegroundColor Yellow
            }
            $buffer = [System.Text.Encoding]::UTF8.GetBytes("OK")
        } 
        elseif ($path -eq "/data") {
            $json = '{"isLocked": "' + $global:status + '", "user": "' + $global:user + '"}'
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
            $res.ContentType = "application/json"
        } 
        else {
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $res.ContentType = "text/html"
        }

        $res.ContentLength64 = $buffer.Length
        $res.OutputStream.Write($buffer, 0, $buffer.Length)
        $res.Close()
    }
} finally {
    $listener.Stop()
}
