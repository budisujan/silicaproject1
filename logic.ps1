# Konfigurasi
$port = 3000
$ip = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).IPAddress[0]
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")
$listener.Start()

# Logika Game
$gameState = @{
    winner = ""
    isLocked = $false
}

Write-Host "--- SERVER BEL AKTIF ---" -ForegroundColor Cyan
Write-Host "Minta teman kamu buka: http://$ip:$port" -ForegroundColor Yellow
Write-Host "Tekan Ctrl+C untuk berhenti."

# Fungsi untuk menangani file HTML
function Get-Html {
    return @"
<!DOCTYPE html>
<html>
<head>
    <title>LAN Quiz Bell</title>
    <style>
        body { font-family: sans-serif; text-align: center; background: #222; color: #fff; padding-top: 50px; }
        #btn { 
            width: 250px; height: 250px; border-radius: 50%; border: 10px solid #444;
            background: radial-gradient(#ff4b2b, #ff416c); color: white; font-size: 30px; 
            font-weight: bold; cursor: pointer; box-shadow: 0 10px #800;
        }
        #btn:active { transform: translateY(5px); box-shadow: 0 5px #800; }
        #btn:disabled { background: #555; box-shadow: none; cursor: not-allowed; opacity: 0.5; }
        .status { font-size: 24px; margin-top: 20px; color: #f1c40f; }
        .username { margin-bottom: 20px; font-size: 18px; color: #00ff00; }
    </style>
</head>
<body>
    <div class="username">User: <span id="myName"></span></div>
    <button id="btn" onclick="buzz()">TEKAN BEL!</button>
    <div id="status" class="status">Menunggu...</div>

    <script>
        const randName = "User" + Math.floor(Math.random() * 999);
        const myName = prompt("Masukkan ID:", randName) || randName;
        document.getElementById('myName').innerText = myName;

        const btn = document.getElementById('btn');
        const status = document.getElementById('status');
        const audio = new Audio('https://www.soundjay.com/buttons/sounds/beep-01a.mp3');

        function buzz() {
            fetch('/buzz?user=' + myName);
        }

        // Cek status server setiap 0.5 detik (Polling)
        setInterval(() => {
            fetch('/state')
                .then(r => r.json())
                .then(data => {
                    if (data.isLocked) {
                        btn.disabled = true;
                        status.innerText = "PEMENANG: " + data.winner;
                        if(data.winner === myName) { status.innerText = "ANDA PEMENANGNYA!"; }
                    } else {
                        btn.disabled = false;
                        status.innerText = "SIAP!";
                    }
                });
        }, 500);
    </script>
</body>
</html>
"@
}

# Loop Server Utama
while ($listener.IsListening) {
    $context = $listener.GetContext()
    $req = $context.Request
    $res = $context.Response

    $url = $req.RawUrl
    $res.ContentType = "text/html"

    if ($url -eq "/") {
        $buffer = [System.Text.Encoding]::UTF8.GetBytes((Get-Html))
    } 
    elseif ($url -like "/buzz*") {
        if (-not $gameState.isLocked) {
            $user = $req.QueryString["user"]
            $gameState.winner = $user
            $gameState.isLocked = $true
            Write-Host "BZZZZT! $user menekan bel!" -ForegroundColor Red
            
            # Reset otomatis setelah 10 detik
            $timer = New-Object System.Timers.Timer(10000)
            Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
                $Global:gameState.isLocked = $false
                $Global:gameState.winner = ""
                Unregister-Event -SourceIdentifier $EventSubscriber.SourceIdentifier
            } | Out-Null
            $timer.AutoReset = $false
            $timer.Start()
        }
        $buffer = [System.Text.Encoding]::UTF8.GetBytes('{"status":"ok"}')
    }
    elseif ($url -eq "/state") {
        $res.ContentType = "application/json"
        $json = '{"winner":"' + $gameState.winner + '", "isLocked":' + $gameState.isLocked.ToString().ToLower() + '}'
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
    }

    $res.ContentLength64 = $buffer.Length
    $res.OutputStream.Write($buffer, 0, $buffer.Length)
    $res.Close()
}
