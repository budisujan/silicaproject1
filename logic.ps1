$port = 3000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")

# SERVER HANYA TEMPAT MENITIP DUA VARIABEL INI
$global:tombolTerkunci = "false"
$global:pemenangId = ""

$html = @"
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Bel Interaktif</title>
    <style>
        body { display: flex; flex-direction: column; justify-content: center; align-items: center; height: 100vh; margin: 0; background: #f0f0f0; font-family: sans-serif; }
        #myIdText { font-size: 18px; background: white; padding: 10px 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); margin-bottom: 20px; border-left: 5px solid #3498db; }
        .btn-bel { padding: 30px 60px; font-size: 28px; font-weight: bold; color: white; background-color: #3498db; border: none; border-radius: 15px; cursor: pointer; box-shadow: 0 8px #2980b9; }
        .btn-bel:active { transform: translateY(4px); box-shadow: 0 4px #1c5980; }
        .btn-bel:disabled { background-color: #bdc3c7 !important; box-shadow: none !important; opacity: 0.7; cursor: not-allowed; }
        #status { margin-top: 20px; font-weight: bold; font-size: 20px; color: #2ecc71; }
        .btn-reset { margin-top: 30px; padding: 10px; background: #e74c3c; color: white; border: none; cursor: pointer; border-radius: 5px; }
    </style>
</head>
<body>

    <div id="myIdText">Mendaftarkan...</div>
    <button id="btnBel" class="btn-bel" onclick="eksekusiBel()">BEL BIRU</button>
    <div id="status">Status: Siap</div>
    
    <button class="btn-reset" onclick="resetServer()">RESET BEL SEMUA ORANG</button>

    <script>
        // 1. GENERATE ID UNIK OTOMATIS
        const idDefault = 'User_' + Math.floor(1000 + Math.random() * 9000);
        const myId = prompt("Masukkan Username Anda:", idDefault) || idDefault;
        document.getElementById('myIdText').innerText = "ID Anda: " + myId;

        const btn = document.getElementById('btnBel');
        const statusText = document.getElementById('status');

        // 2. FUNGSI SUARA (BEEP)
        function bunyi() {
            try {
                const ctx = new (window.AudioContext || window.webkitAudioContext)();
                const osc = ctx.createOscillator();
                const gain = ctx.createGain();
                osc.type = 'sawtooth';
                osc.frequency.setValueAtTime(440, ctx.currentTime);
                gain.gain.setValueAtTime(0.1, ctx.currentTime);
                osc.connect(gain); gain.connect(ctx.destination);
                osc.start(); setTimeout(() => osc.stop(), 800);
            } catch(e) {}
        }

        // 3. MEKANISME TEKAN
        async function eksekusiBel() {
            bunyi();
            // Kirim ke server agar orang lain juga disable
            try {
                await fetch('/update?lock=true&user=' + encodeURIComponent(myId));
            } catch(e) {
                // Jika mencoba tanpa server, tetap disable sendiri
                btn.disabled = true;
                statusText.innerText = "Status: Terkunci (Tanpa Server)";
            }
        }

        async function resetServer() {
            try {
                await fetch('/update?lock=false&user=');
            } catch(e) {
                btn.disabled = false;
                statusText.innerText = "Status: Siap";
            }
        }

        // 4. MONITORING (Hanya jalan jika ada server)
        setInterval(async () => {
            try {
                const res = await fetch('/data');
                const data = await res.json();
                if (data.isLocked === "true") {
                    btn.disabled = true;
                    statusText.innerText = "DITEKAN OLEH: " + data.user;
                    statusText.style.color = "#e74c3c";
                } else {
                    btn.disabled = false;
                    statusText.innerText = "Status: SIAP";
                    statusText.style.color = "#2ecc71";
                }
            } catch (e) {
                // Jika server tidak ada, biarkan mekanisme mandiri bekerja
            }
        }, 500);
    </script>
</body>
</html>
"@

Write-Host "--- SERVER AKTIF ---" -ForegroundColor Cyan
Write-Host "Buka browser ke: http://localhost:3000"
$listener.Start()

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $res.AddHeader("Access-Control-Allow-Origin", "*")

    if ($req.Url.LocalPath -eq "/data") {
        $json = '{"isLocked": "' + $global:tombolTerkunci + '", "user": "' + $global:pemenangId + '"}'
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
    } 
    elseif ($req.Url.LocalPath -eq "/update") {
        $global:tombolTerkunci = $req.QueryString["lock"]
        $global:pemenangId = $req.QueryString["user"]
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("OK")
    } 
    else {
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $res.ContentType = "text/html"
    }

    $res.ContentLength64 = $buffer.Length
    $res.OutputStream.Write($buffer, 0, $buffer.Length)
    $res.Close()
}
