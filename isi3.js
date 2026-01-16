const outputLog = document.getElementById('output');
const termInput = document.getElementById('termInput');
const promptPath = document.getElementById('promptPath');
const dlHandler = document.getElementById('dlHandler');

let isAuth = false;
let currentUnit = "";

// Database dengan link yang sudah di-encode ke Base64
const silicaAuth = {
    "morning_star": {
        serial: "65a#Y4",
        file: "REC_01_HALO.raw",
        link: "aHR0cHM6Ly9kcml2ZS5nb29nbGUuY29tL3VjP2V4cG9ydD1kb3dubG9hZCZpZD0xampHTWxkUnlHOHJObjhUdnUtU2JwVDV0N1pTYnBEXzg=",
        desc: "user:e_nussbaum"
    },
    "fallen_star": {
        serial: "65a#Y4",
        file: "REC_02_ETERNAL.raw",
        link: "aHR0cHM6Ly9kcml2ZS5nb29nbGUuY29tL3VjP2V4cG9ydD1kb3dubG9hZCZpZD0xMHRiS01Wck81LUFBV3lUeDlraTI5ZG9KeWo3cExGSGc=",
        desc: "user:a_fitzwilliam"
    },
    "outer_space": {
        serial: "65a#Y4",
        file: "REC_03_AEGIS.raw",
        link: "aHR0cHM6Ly9kcml2ZS5nb29nbGUuY29tL3VjP2V4cG9ydD1kb3dubG9hZCZpZD0xS184anI4bUxadlgwa1M3dTBWbVFsSUNsbDhCOWhId1Y=",
        desc: "user:l_richer"
    },
    "dark_memories": {
        serial: "65a#Y4",
        file: "SILICA_AI_1990.avi",
        link: "aHR0cHM6Ly9kcml2ZS5nb29nbGUuY29tL3VjP2V4cG9ydD1kb3dubG9hZCZpZD0xQ0d5ejk1YXNOamZoWkZUd0Q3Rl9vVWk0X3dZTmV5Zk8=",
        desc: "user:t_anderson"
    },
    "soul_symphony": {
        serial: "65a#Y4",
        file: "DEMO_HELENA.avi",
        link: "aHR0cHM6Ly9kcml2ZS5nb29nbGUuY29tL3VjP2V4cG9ydD1kb3dubG9hZCZpZD0xUmV0YTRqSnRSNmc2WHFDc2M0SGJmNVdGMmJxeXN2elA=",
        desc: "user:h_moreau"
    },
    "phoenix_fire": {
        serial: "65a#Y4",
        file: "CLODES_NOTE.raw",
        link: "aHR0cHM6Ly9kcml2ZS5nb29nbGUuY29tL3VjP2V4cG9ydD1kb3dubG9hZCZpZD0xUlk2OUJZbGM0aWRVOWU4NElrVnZYdFJwMmZxWXZ1bEU=",
        desc: "user:h_clode"
    }
};

termInput.addEventListener('keypress', function(e) {
    if (e.key === 'Enter') {
        const val = this.value.trim();
        const args = val.split(' ');
        const cmd = args[0].toLowerCase();
        const target = args[1];

        writeLine(`${promptPath.innerText} ${val}`, "#fff");

        if (cmd === 'clear') {
            outputLog.innerHTML = '';
        } else if (cmd === 'help') {
            showHelp();
        } else if (!isAuth) {
            handleLogin(cmd, target);
        } else {
            handleSystem(cmd, target);
        }

        this.value = '';
        scrollToBottom();
    }
});

function showHelp() {
    if (!isAuth) {
        writeLine(">> AVAILABLE ENCRYPTED UNITS:", "#00ffff");
        Object.keys(silicaAuth).forEach(unit => {
            writeLine(` - ${unit}`, "#888");
        });
        writeLine(" - [UNKNOWN_FILE] STATUS: NOT_DOWNLOADED", "#ffaa00");
        writeLine("<br>>> AUTH REQUIRED: [unit_name] [serial_number]", "#fff");
    } else {
        writeLine(">> COMMANDS: ls, cat [file], open [file], clear, logout", "#888");
    }
}

function handleLogin(name, serial) {
    if (silicaAuth[name] && silicaAuth[name].serial === serial) {
        writeLine(">> VALIDATING IDENTITY...", "#00ffff");
        setTimeout(() => {
            isAuth = true;
            currentUnit = name;
            promptPath.innerText = `SYSTEM@${name.toUpperCase()}:~$`;
            writeLine(">> ACCESS GRANTED. FILESYSTEM MOUNTED.", "#00ff00");
        }, 800);
    } else {
        writeLine(">> ERROR: ACCESS DENIED.", "#ff0000");
    }
}

function handleSystem(cmd, target) {
    const data = silicaAuth[currentUnit];
    switch(cmd) {
        case 'ls':
            writeLine(`[FILE] ${data.file}<br>[FILE] manifest.txt`, "#00ff00");
            break;
        case 'cat':
            if (target === 'manifest.txt') {
                writeLine(`<div class="data-found"><strong>${data.desc}</strong><br>STATUS: ENCRYPTED_GCM<br>SIZE: 14.2MB</div>`, "#00ff00");
            } else { writeLine("ERR: FILE NOT FOUND.", "#ff0000"); }
            break;
        case 'open':
            if (target === data.file) {
                startDownload(data.link);
            } else { writeLine("ERR: FILE NOT FOUND.", "#ff0000"); }
            break;
        case 'logout':
            isAuth = false;
            promptPath.innerText = "SYSTEM@DECODER:~$";
            writeLine(">> LOGGED OUT.", "#ff0000");
            break;
        default:
            writeLine(`UNKNOWN COMMAND: ${cmd}`, "#ff0000");
    }
}

function startDownload(encodedUrl) {
    let p = 0;
    const line = document.createElement('div');
    outputLog.appendChild(line);
    const intv = setInterval(() => {
        p += 10;
        line.innerHTML = `>> DOWNLOADING: [${'#'.repeat(p/10)}${'.'.repeat(10-p/10)}] ${p}%`;
        scrollToBottom();
        if (p >= 100) {
            clearInterval(intv);
            writeLine(">> SUCCESS: DATA RECEIVED.", "#00ff00");
            
            // Proses decoding Base64 di sini
            const decodedUrl = atob(encodedUrl);
            dlHandler.src = decodedUrl;
        }
    }, 150);
}

function writeLine(text, color) {
    const div = document.createElement('div');
    div.style.color = color;
    div.innerHTML = text;
    outputLog.appendChild(div);
}

function scrollToBottom() {
    outputLog.scrollTop = outputLog.scrollHeight;
                }
