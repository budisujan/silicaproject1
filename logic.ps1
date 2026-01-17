$port = 3000
$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://*:$port/")

# HANYA MENYIMPAN VARIABEL DASAR
$global:status = "false"
$global:user = ""

$html = @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Bel Windows 7</title>
    <style>
        body { text-align: center; font-family: sans-serif; padding-top: 50px; background: #dfe6e9; }
        .bel { padding: 40px 80px; font-size: 30px; cursor: pointer; background: #0984e3; color: white; border-radius: 15px; border: none; box-shadow: 0 8px #0866af; }
        .bel:disabled { background: #b2bec3; box-shadow: none; transform: translateY(5px); }
        .reset { margin-top: 50px; padding: 10px 20px; background: #d63031; color: white; border: none; cursor: pointer; }
        #pesan { font-size: 24px; margin-bottom: 20px; font-weight: bold; }
    </style>
</head>
<body>
    <div id="pesan">Menghubungkan...</div>
    <button id="btnBel" class="bel" onclick="tekanBel()">TEKAN BEL</button>
    <br>
    <button class="reset" onclick="resetServer()">RESET SEMUA TOMBOL</button>

    <script>
        let nama = prompt("Nama Anda:") || "User";
        
        // 1. MEKANISME TEKAN
        async function tekanBel() {
            // Beritahu server kita mengunci dan mengirim ID
            await fetch('/update?status=true&user=' + encodeURIComponent(nama));
        }

        // 2. MEKANISME RESET (Membuka kunci dari sisi client)
        async function resetServer() {
            await fetch('/update?status=false&user=');
        }

        // 3. MEKANISME MONITORING (Looping terus menerus)
        setInterval(async () => {
            try {
                const res = await fetch('/data');
                const data = await res.json();
                
                const btn = document.getElementById('btnBel');
                const p = document.getElementById('pesan');

                if (data.status === "true") {
                    btn.disabled = true;
                    p.innerText = "DITEKAN OLEH: " + data.user;
                    p.style.color = "red";
                } else {
                    btn.disabled = false;
                    p.innerText = "SIAP!";
                    p.style.color = "green";
                }
            } catch (e) {}
        }, 500);
    </script>
</body>
</html>
"@

Write-Host "Server Berjalan di http://localhost:3000" -ForegroundColor Green
$listener.Start()

while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $req = $ctx.Request
    $res = $ctx.Response
    $res.AddHeader("Access-Control-Allow-Origin", "*")

    if ($req.Url.LocalPath -eq "/data") {
        # Hanya mengirim variabel yang tersimpan
        $json = '{"status": "' + $global:status + '", "user": "' + $global:user + '"}'
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($json)
        $res.ContentType = "application/json"
    } 
    elseif ($req.Url.LocalPath -eq "/update") {
        # Hanya menyimpan variabel dari request HTML
        $global:status = $req.QueryString["status"]
        $global:user = $req.QueryString["user"]
        $buffer = [System.Text.Encoding]::UTF8.GetBytes("Updated")
    } 
    else {
        # Mengirim tampilan HTML
        $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
        $res.ContentType = "text/html"
    }

    $res.ContentLength64 = $buffer.Length
    $res.OutputStream.Write($buffer, 0, $buffer.Length)
    $res.Close()
}
