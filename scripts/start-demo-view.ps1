param([switch]$NoBrowser)
$ErrorActionPreference = 'Stop'

$accessDir = Join-Path $env:USERPROFILE 'Documents\Codex\pickerbot-access'
$key = Join-Path $accessDir 'pickerbot_mini'
$knownHosts = Join-Path $accessDir 'known_hosts'
$stateFile = Join-Path $env:TEMP 'pickerbot-demo-view.json'
$watcherScript = Join-Path $PSScriptRoot 'watch-demo-view.ps1'
$repoRoot = Split-Path -Parent $PSScriptRoot
# A dashboard.html 2026-09-24-én megszűnt — minden szenzor (kamerák, térkép, IR, LiDAR
# felülnézet, 3D pontfelhő) a control_panel.html-be került, tehát csak egy URL van.
$url = 'http://127.0.0.1:8902/scripts/control_panel.html'
$videoProbeUrls = @(
    'http://127.0.0.1:8080/snapshot?topic=/usb_cam/image_raw&width=320&height=240&quality=55',
    'http://127.0.0.1:8080/snapshot?topic=/camera/rgb/image_raw&width=320&height=240&quality=55'
)

function Get-LoopbackListenerPid([int]$Port) {
    # Get-NetTCPConnection nem mindig látja a magasabb jogosultsággal indított folyamat socketjét.
    # A netstat ugyanebben a helyzetben is megadja a tulajdonos PID-jét.
    $pattern = '^\s*TCP\s+(?:127\.0\.0\.1|\[::1\]):' + $Port + '\s+\S+\s+LISTENING\s+(\d+)\s*$'
    foreach ($line in (& netstat.exe -ano -p tcp)) {
        if ($line -match $pattern) { return [int]$Matches[1] }
    }
    return $null
}

if (-not (Test-Path -LiteralPath $knownHosts)) {
    throw 'A Pickerbot known_hosts fájl hiányzik.'
}
if (Test-Path -LiteralPath $stateFile) {
    $previous = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $oldServer = Get-Process -Id $previous.serverPid -ErrorAction SilentlyContinue
    $oldTunnel = Get-Process -Id $previous.tunnelPid -ErrorAction SilentlyContinue
    $oldWatcher = $null
    if ($previous.PSObject.Properties.Name -contains 'watcherPid') {
        $oldWatcher = Get-Process -Id $previous.watcherPid -ErrorAction SilentlyContinue
    }
    if ($oldServer -and $oldServer.ProcessName -ne 'python') { $oldServer = $null }
    if ($oldTunnel -and $oldTunnel.ProcessName -notin @('ssh', 'plink')) { $oldTunnel = $null }
    if ($oldWatcher -and $oldWatcher.ProcessName -notin @('powershell', 'pwsh')) { $oldWatcher = $null }

    if ($oldTunnel -and -not $oldTunnel.HasExited) {
        try {
            foreach ($videoProbeUrl in $videoProbeUrls) {
                $videoProbe = Invoke-WebRequest $videoProbeUrl -UseBasicParsing -TimeoutSec 15
                if ($videoProbe.StatusCode -ne 200 -or $videoProbe.Headers['Content-Type'] -notlike 'image/jpeg*') {
                    throw "A videóalagút nem ad élő JPEG-képet: $videoProbeUrl"
                }
            }
        } catch {
            Stop-Process -Id $oldTunnel.Id -Force -ErrorAction SilentlyContinue
            $oldTunnel = $null
        }
    }

    if ($oldServer -and $oldTunnel -and $oldWatcher -and
        -not $oldServer.HasExited -and -not $oldTunnel.HasExited -and -not $oldWatcher.HasExited) {
        Write-Host "A bemutatónézet és az SSH-alagút már fut: $url"
        if (-not $NoBrowser) { Start-Process $url }
        exit 0
    }
} else {
    $oldServer = $null
    $oldTunnel = $null
    $oldWatcher = $null
}

# Egy korábban rendszergazdaként indított helyi szerverhez a jelenlegi folyamat nem mindig fér hozzá
# leállításra. Ha az állapotfájl hiányzik, de a helyes oldal már él a 8902-es porton, vegyük át a
# meglévő Python-folyamatot ahelyett, hogy hibával leállnánk vagy második szervert indítanánk.
if (-not $oldServer) {
    $serverListenerPid = Get-LoopbackListenerPid 8902
    if ($serverListenerPid) {
        $candidateServer = Get-Process -Id $serverListenerPid -ErrorAction SilentlyContinue
        if ($candidateServer -and $candidateServer.ProcessName -eq 'python') {
            try {
                $serverProbe = Invoke-WebRequest $url -UseBasicParsing -TimeoutSec 5
                if ($serverProbe.StatusCode -eq 200) { $oldServer = $candidateServer }
            } catch { $oldServer = $null }
        }
    }
}

# Ugyanígy átvehető egy állapotfájl nélkül maradt, de ténylegesen egészséges SSH-alagút.
if (-not $oldTunnel) {
    $tunnelListenerPid = Get-LoopbackListenerPid 8080
    if ($tunnelListenerPid) {
        $candidateTunnel = Get-Process -Id $tunnelListenerPid -ErrorAction SilentlyContinue
        if ($candidateTunnel -and $candidateTunnel.ProcessName -in @('ssh', 'plink')) {
            try {
                foreach ($videoProbeUrl in $videoProbeUrls) {
                    $videoProbe = Invoke-WebRequest $videoProbeUrl -UseBasicParsing -TimeoutSec 15
                    if ($videoProbe.StatusCode -ne 200 -or $videoProbe.Headers['Content-Type'] -notlike 'image/jpeg*') {
                        throw 'A meglévő alagút nem egészséges.'
                    }
                }
                $oldTunnel = $candidateTunnel
            } catch { $oldTunnel = $null }
        }
    }
}
foreach ($port in @(if (-not $oldTunnel) { 8080 }; if (-not $oldServer) { 8902 })) {
    $probe = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback, $port)
    try { $probe.Start() }
    catch { throw "A helyi $port port már használatban van." }
    finally { $probe.Stop() }
}

$sshArgs = @(
    '-N', '-L', '127.0.0.1:8080:127.0.0.1:8080',
    '-i', $key,
    '-o', 'BatchMode=yes',
    '-o', 'ExitOnForwardFailure=yes',
    '-o', 'ServerAliveInterval=15',
    '-o', 'ServerAliveCountMax=2',
    '-o', 'StrictHostKeyChecking=yes',
    '-o', "UserKnownHostsFile=$knownHosts",
    'wheeltec@192.168.123.50'
)
$tunnel = $oldTunnel
$server = $oldServer
$watcher = $oldWatcher
$newTunnel = $null
$newServer = $null
$newWatcher = $null
try {
    if (-not $tunnel) {
        $passwordFile = $null
        try {
            $keyReadable = $false
            if (Test-Path -LiteralPath $key) {
                try {
                    $keyStream = [System.IO.File]::OpenRead($key)
                    $keyStream.Dispose()
                    $keyReadable = $true
                } catch { $keyReadable = $false }
            }
            if ($keyReadable) {
                $tunnel = Start-Process -FilePath 'ssh.exe' -ArgumentList $sshArgs -PassThru -WindowStyle Hidden
            } else {
                # A Codex Windows-fiók néha nem olvashatja a privát kulcsot.
                # A dokumentált jelszó csak rövid életű helyi fájlba kerül; a hostkulcsot rögzítjük.
                $plink = Get-Command 'plink.exe' -ErrorAction SilentlyContinue
                if (-not $plink) { throw 'Az SSH-kulcs nem olvasható, és a PuTTY plink.exe sem érhető el.' }
                $readme = Get-Content -LiteralPath (Join-Path $repoRoot 'README.md') -Raw
                # Windows PowerShell 5.1 BOM nélküli UTF-8 README-t a rendszer kódlapjával olvashat.
                # Az ékezetes mezőnév helyett a stabil "Sudo" oszlopkezdetre illesztünk.
                $passwordMatch = [regex]::Match($readme, '\|\s*Sudo\s+[^|]*\|\s*`([^`]+)`')
                if (-not $passwordMatch.Success) { throw 'A dokumentált robotjelszó nem található.' }
                $hostKeyLine = & ssh-keygen.exe -lf $knownHosts |
                    Where-Object { $_ -match '192\.168\.123\.50' } | Select-Object -First 1
                if ($hostKeyLine -notmatch 'SHA256:[A-Za-z0-9+/]+') {
                    throw 'A robot hostkulcsának ujjlenyomata nem olvasható.'
                }
                $hostKey = $Matches[0]
                $passwordFile = Join-Path $env:TEMP ('pickerbot-demo-pw-' + [guid]::NewGuid().ToString('N') + '.txt')
                [System.IO.File]::WriteAllText($passwordFile, $passwordMatch.Groups[1].Value + "`n", [System.Text.UTF8Encoding]::new($false))
                $plinkArgs = @('-ssh', '-batch', '-N', '-L', '127.0.0.1:8080:127.0.0.1:8080',
                    '-l', 'wheeltec', '-pwfile', $passwordFile, '-hostkey', $hostKey, '192.168.123.50')
                $tunnel = Start-Process -FilePath $plink.Source -ArgumentList $plinkArgs -PassThru -WindowStyle Hidden
            }
            $newTunnel = $tunnel
            $tunnelReady = $false
            for ($attempt = 0; $attempt -lt 30; $attempt++) {
                Start-Sleep -Milliseconds 500
                if ($tunnel.HasExited) { break }
                $probe = [System.Net.Sockets.TcpClient]::new()
                try {
                    $probe.Connect('127.0.0.1', 8080)
                    $tunnelReady = $true
                    break
                } catch {
                    # Wi-Fi-n az SSH-hitelesítés a korábbi fix 2 másodpercnél tovább tarthat.
                } finally {
                    $probe.Dispose()
                }
            }
            if (-not $tunnelReady) { throw 'Az SSH-alagút 15 másodperc alatt sem indult el.' }
        } finally {
            if ($passwordFile) { Remove-Item -LiteralPath $passwordFile -ErrorAction SilentlyContinue }
        }
    }

    if (-not $server) {
        $serverArgs = @((Join-Path $PSScriptRoot 'demo_server.py'), '--port', '8902')
        $server = Start-Process -FilePath 'python.exe' -ArgumentList $serverArgs -PassThru -WindowStyle Hidden
        $newServer = $server
        Start-Sleep -Seconds 2
        if ($server.HasExited) { throw 'A helyi bemutatóoldal nem indult el.' }
    }

    if (-not $watcher) {
        if (-not (Test-Path -LiteralPath $watcherScript)) { throw 'A videóalagút-őrző szkript hiányzik.' }
        $watcherArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $watcherScript)
        $watcher = Start-Process -FilePath 'powershell.exe' -ArgumentList $watcherArgs -PassThru -WindowStyle Hidden
        $newWatcher = $watcher
        Start-Sleep -Milliseconds 500
        if ($watcher.HasExited) { throw 'A videóalagút automatikus őrzője nem indult el.' }
    }

    @{ tunnelPid = $tunnel.Id; serverPid = $server.Id; watcherPid = $watcher.Id } |
        ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
    if (-not $NoBrowser) { Start-Process $url }
    Write-Host "Bemutató: $url"
    Write-Host 'Leállítás: scripts\stop-demo-view.ps1'
} catch {
    if ($newWatcher -and -not $newWatcher.HasExited) { Stop-Process -Id $newWatcher.Id -ErrorAction SilentlyContinue }
    if ($newServer -and -not $newServer.HasExited) { Stop-Process -Id $newServer.Id -ErrorAction SilentlyContinue }
    if ($newTunnel -and -not $newTunnel.HasExited) { Stop-Process -Id $newTunnel.Id -ErrorAction SilentlyContinue }
    throw
}
