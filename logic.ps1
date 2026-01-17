$port = 3000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")

$global:isLocked = $false
$global:lockedBy = ""

# Konten Tampilan Tombol
$htmlContent = @"
<!DOCTYPE html>
<html lang="id">
<head>
    <meta charset="UTF-8">
    <title>Bel Interaktif</title>
    <style>
        body { display: flex; flex-direction: column; justify-content: center; align-items: center; height: 100vh; gap: 20px; background-color: #f0f2f5; font-family: sans-serif; }
        .btn-bel { padding: 30px 60px; font-size: 32px; font-weight: bold; color: white; border: none; border-radius: 15px; cursor: pointer; box-shadow: 0 8px #2980b9; background-color: #3498db; }
        button:disabled { background-color: #bdc3c7 !important; cursor: not-allowed; box-shadow: none !important; opacity: 0.6; }
        #statusInfo { font-weight: bold; font-size: 20px; color: #27ae60; }
    </style>
</head>
<body>
    <div id="statusInfo">SIAP!</div>
    <button id="btn" class="btn-bel" onclick="tekan()">BEL BIRU</button>
    <script>
        const user = prompt("Username:") || "Anonim";
        async function tekan() {
            await fetch('/press?user=' + encodeURIComponent(user));
        }
        setInterval(async () => {
            try {
                const res = await fetch('/status');
                const data = await res.json();
                const btn = document.getElementById('btn');
                const info = document.getElementById('statusInfo');
                if(data.isLocked) {
                    btn.disabled = true;
                    info.innerText = "🔒 DITEKAN OLEH: " + data.lockedBy;
                    info.style.color = "#e74c3c";
                } else {
                    btn.disabled = false;
                    info.innerText = "✅ SIAP!";
                    info.style.color = "#27ae60";
                }
            } catch(e) {}
        }, 500);
    </script>
</body>
</html>
"@

Write-Host "Server Berjalan! Buka http://localhost:$port di browser Anda." -ForegroundColor Green
$listener.Start()

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $req = $context.Request
        $res = $context.Response
        $path = $req.Url.LocalPath

        if ($path -eq "/") {
            # Mengirimkan Halaman HTML
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
            $res.ContentType = "text/html"
        } 
        elseif ($path -eq "/press") {
            if (-not $global:isLocked) {
                $global:isLocked = $true
                $global:lockedBy = $req.QueryString["user"]
                Write-Host "[!] Ditekan oleh: $($global:lockedBy)" -ForegroundColor Yellow
                $timer = [System.Timers.Timer]::new(10000)
                $timer.AutoReset = $false
                Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action { 
                    $global:isLocked = $false; Write-Host "Reset!" -ForegroundColor Green 
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

        $res.ContentLength64 = $buffer.Length
        $res.OutputStream.Write($buffer, 0, $buffer.Length)
        $res.Close()
    }
} finally { $listener.Stop() }
