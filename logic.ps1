# Jalankan di PowerShell: Menyiapkan Server HTTP di Port 8080
$port = 8080
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")
$listener.Start()

$players = @{}      # Variabel untuk menyimpan posisi pemain
$gameState = @{     # Status game (siapa pemenangnya dan kapan tombol aktif lagi)
    winner = ""
    disabledUntil = 0
}

Write-Host "Server jalan di http://localhost:$port" -ForegroundColor Cyan
Write-Host "Bagikan IP komputermu ke teman dalam satu jaringan LAN!"

try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $request = $context.Request
        $response = $context.Response

        # Routing URL
        $query = $request.QueryString
        $id = $query["id"]
        $x = $query["x"]
        $y = $query["y"]
        $action = $query["action"] # Untuk mendeteksi klik tombol

        if ($id) {
            $currentTime = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()

            # Logika Jika Ada yang Klik Tombol
            if ($action -eq "klik" -and $currentTime -gt $gameState.disabledUntil) {
                $gameState.winner = $id
                $gameState.disabledUntil = $currentTime + 10000 # Lock 10 detik
            }

            # Update posisi pemain
            $players[$id] = @{ x = $x; y = $y; lastUpdate = $currentTime }

            # Hapus pemain yang tidak aktif > 5 detik
            $keys = $players.Keys | ForEach-Object { $_ }
            foreach ($k in $keys) {
                if ($currentTime - $players[$k].lastUpdate -gt 5000) { $players.Remove($k) }
            }

            # Response JSON
            $data = @{ players = $players; game = $gameState; serverTime = $currentTime }
            $buffer = [System.Text.Encoding]::UTF8.GetBytes(($data | ConvertTo-Json))
            $response.ContentType = "application/json"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        } else {
            # Kirim halaman HTML jika akses biasa (tanpa ID)
            $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>LAN Fast Clicker</title>
    <style>
        body { margin: 0; overflow: hidden; background: #222; font-family: sans-serif; color: white; }
        .player { width: 30px; height: 30px; position: absolute; border-radius: 50%; transition: 0.1s; display: flex; align-items: center; justify-content: center; font-size: 10px; }
        #myBox { background: #00ff00; z-index: 10; border: 2px solid white; }
        .other { background: #ff4d4d; }
        .name-tag { position: absolute; top: -20px; white-space: nowrap; font-weight: bold; }
        #game-ui { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); text-align: center; width: 100%; }
        #mainBtn { padding: 30px 60px; font-size: 30px; cursor: pointer; border-radius: 15px; border: none; background: #3498db; color: white; box-shadow: 0 8px #2980b9; }
        #mainBtn:active { box-shadow: 0 2px #2980b9; transform: translateY(4px); }
        #mainBtn:disabled { background: #555; box-shadow: none; cursor: not-allowed; opacity: 0.7; }
        #winnerText { font-size: 40px; color: gold; margin-bottom: 20px; height: 50px; text-shadow: 2px 2px 5px black; }
    </style>
</head>
<body>
    <div id="game-ui">
        <div id="winnerText"></div>
        <button id="mainBtn">PENCET CEPAT!</button>
    </div>
    <div id="myBox" class="player"><span class="name-tag">YOU</span></div>

    <script>
        const myBox = document.getElementById('myBox');
        const mainBtn = document.getElementById('mainBtn');
        const winnerText = document.getElementById('winnerText');
        
        // Input ID di awal
        let myId = prompt("Masukkan Username Unik Anda:", "Player_" + Math.floor(Math.random() * 1000));
        if (!myId) myId = "Guest" + Math.floor(Math.random() * 100);

        const bell = new AudioContext();

        function playBell() {
            const osc = bell.createOscillator();
            const gain = bell.createGain();
            osc.type = "sawtooth";
            osc.frequency.value = 440;
            gain.gain.value = 0.1;
            osc.connect(gain);
            gain.connect(bell.destination);
            osc.start();
            setTimeout(() => osc.stop(), 1000);
        }

        document.addEventListener('mousemove', (e) => {
            myBox.style.left = e.pageX + 'px';
            myBox.style.top = e.pageY + 'px';
            sync(e.pageX, e.pageY);
        });

        mainBtn.addEventListener('click', () => {
            sync(parseInt(myBox.style.left), parseInt(myBox.style.top), true);
        });

        async function sync(x, y, isClick = false) {
            let url = `?id=\${encodeURIComponent(myId)}&x=\${x}&y=\${y}`;
            if (isClick) url += '&action=klik';

            try {
                const res = await fetch(url);
                const data = await res.json();
                updateUI(data);
            } catch (e) {}
        }

        function updateUI(data) {
            const { players, game, serverTime } = data;

            // Update Status Tombol & Pemenang
            if (serverTime < game.disabledUntil) {
                mainBtn.disabled = true;
                winnerText.innerText = "PEMENANG: " + game.winner;
                // Jika baru saja diklik (efek suara lokal)
                if (mainBtn.dataset.active === "true") {
                    playBell();
                    mainBtn.dataset.active = "false";
                }
            } else {
                mainBtn.disabled = false;
                winnerText.innerText = "";
                mainBtn.dataset.active = "true";
            }

            // Render Pemain Lain
            for (let id in players) {
                if (id === myId) continue;
                let el = document.getElementById(id);
                if (!el) {
                    el = document.createElement('div');
                    el.id = id;
                    el.className = 'player other';
                    el.innerHTML = `<span class="name-tag">\${id}</span>`;
                    document.body.appendChild(el);
                }
                el.style.left = players[id].x + 'px';
                el.style.top = players[id].y + 'px';
            }
        }

        // Loop Sinkronisasi tetap jalan meski mouse diam
        setInterval(() => {
            sync(parseInt(myBox.style.left) || 0, parseInt(myBox.style.top) || 0);
        }, 500);
    </script>
</body>
</html>
"@
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.ContentType = "text/html"
            $response.ContentLength64 = $buffer.Length
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
        }
        $response.Close()
    }
} finally {
    $listener.Stop()
}
