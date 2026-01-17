# Konfigurasi Server
$port = 8080
$endpoint = "http://*:$port/"
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($endpoint)
$listener.Start()

# State Global
$global:lastWinner = ""
$global:isLocked = $false
$global:lockTime = [DateTime]::MinValue

Write-Host "Server berjalan di http://$($(ipconfig | findstr [0-9]\.[0-9]\.[0-9]\.[0-9])[0].Split()[-1]):$port"
Write-Host "Tekan Ctrl+C untuk berhenti."

# Konten HTML, CSS, dan JS
$htmlContent = @"
<!DOCTYPE html>
<html>
<head>
    <title>Multiplayer Quiz Bell</title>
    <style>
        body { font-family: sans-serif; text-align: center; background: #2c3e50; color: white; padding-top: 50px; }
        .btn-bell { 
            width: 200px; height: 200px; border-radius: 50%; border: none; 
            background: #e74c3c; box-shadow: 0 10px #c0392b; cursor: pointer;
            font-size: 24px; color: white; font-weight: bold;
        }
        .btn-bell:active { box-shadow: 0 5px #c0392b; transform: translateY(4px); }
        .btn-bell:disabled { background: #7f8c8d; box-shadow: 0 10px #34495e; cursor: not-allowed; }
        #status { margin-top: 20px; font-size: 1.5em; color: #f1c40f; }
        .user-info { position: absolute; top: 10px; right: 10px; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="user-info">User: <span id="myId"></span></div>
    <h1>QUIZ BELL</h1>
    <button id="bellBtn" class="btn-bell" onclick="pushBell()">TEKAN!</button>
    <div id="status">Menunggu...</div>

    <script>
        let myId = "User" + Math.floor(Math.random() * 1000);
        let inputId = prompt("Masukkan Username Anda:", myId);
        myId = inputId || myId;
        document.getElementById('myId').innerText = myId;

        const audio = new Audio('https://www.soundjay.com/buttons/beep-01a.mp3');

        function pushBell() {
            fetch('/push?id=' + encodeURIComponent(myId));
        }

        async function updateStatus() {
            try {
                const res = await fetch('/status');
                const data = await res.json();
                const btn = document.getElementById('bellBtn');
                const statusDiv = document.getElementById('status');

                if (data.isLocked) {
                    btn.disabled = true;
                    statusDiv.innerText = "PEMENANG: " + data.winner;
                    if (data.winner === data.lastWinnerAlert) {
                        // Efek suara hanya dipicu sekali lewat state lokal jika perlu
                    }
                } else {
                    btn.disabled = false;
                    statusDiv.innerText = "Silahkan Tekan!";
                }
            } catch (e) {}
        }

        setInterval(updateStatus, 500);
    </script>
</body>
</html>
"@

# Logic Loop Server
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $request = $context.Request
    $response = $context.Response

    # Reset lock jika sudah 10 detik
    if ($global:isLocked -and (Get-Date) -gt $global:lockTime.AddSeconds(10)) {
        $global:isLocked = $false
        $global:lastWinner = ""
    }

    if ($request.Url.PathAndQuery -eq "/status") {
        $json = "{`"isLocked`": $($global:isLocked | ConvertTo-Json), `"winner`": `"$($global:lastWinner)`"}"
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        $response.ContentType = "application/json"
    }
    elseif ($request.Url.PathAndQuery -like "/push*") {
        if (-not $global:isLocked) {
            $global:isLocked = $true
            $global:lockTime = Get-Date
            $global:lastWinner = $request.QueryString["id"]
            Write-Host "Bell ditekan oleh: $($global:lastWinner)"
        }
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("OK")
    }
    else {
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($htmlContent)
        $response.ContentType = "text/html"
    }

    $response.ContentLength64 = $buffer.Length
    $response.OutputStream.Write($buffer, 0, $buffer.Length)
    $response.Close()
}
