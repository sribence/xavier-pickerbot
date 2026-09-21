# Videóalagút-őrző és mérőnapló a bemutatónézethez.
# Alapból 10 másodpercenként lekér egy JPEG-pillanatképet a helyi alagúton át.
# Ha egymás után többször nem sikerül, a start-demo-view.ps1 -NoBrowser újraindítja a hiányzó alagutat.
# Csak a laptopon fut: a robotot nem érinti, mozgásparancsot nem küld.
# Leállítás: Ctrl+C ebben az ablakban.
param(
    [int]$IntervalSec = 10,
    [int]$TimeoutSec = 8,
    [int]$FailuresBeforeRestart = 2
)
$ErrorActionPreference = 'Continue'

$starter = Join-Path $PSScriptRoot 'start-demo-view.ps1'
$logFile = Join-Path $env:TEMP 'pickerbot-demo-watch.csv'
$probeUrl = 'http://127.0.0.1:8080/snapshot?topic=/usb_cam/image_raw&quality=55'

if (-not (Test-Path -LiteralPath $starter)) {
    throw 'A start-demo-view.ps1 nem található.'
}
if (-not (Test-Path -LiteralPath $logFile)) {
    'ido,siker,masodperc,bajt,ujrainditas' | Set-Content -LiteralPath $logFile -Encoding UTF8
}

Write-Host "Alagút-őrző fut. Napló: $logFile"
Write-Host 'Leállítás: Ctrl+C'

$fails = 0
while ($true) {
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $ok = $false
    $bytes = 0
    try {
        $response = Invoke-WebRequest -Uri $probeUrl -UseBasicParsing -TimeoutSec $TimeoutSec
        if ($response.StatusCode -eq 200 -and $response.Headers['Content-Type'] -like 'image/jpeg*') {
            $ok = $true
            $bytes = $response.RawContentLength
        }
    } catch {
        $ok = $false
    }
    $stopwatch.Stop()
    $seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)

    $restarted = 0
    if ($ok) {
        $fails = 0
    } else {
        $fails++
        if ($fails -ge $FailuresBeforeRestart) {
            Write-Host ("[{0}] Nincs kép {1} mérés óta, alagút újraindítása..." -f (Get-Date -Format 'HH:mm:ss'), $fails)
            try {
                & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $starter -NoBrowser | Out-Null
            } catch {
                Write-Host 'Az újraindítás hibával állt le, a következő körben újra próbálom.'
            }
            $restarted = 1
            $fails = 0
        }
    }

    $line = '{0},{1},{2},{3},{4}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), [int]$ok, $seconds, $bytes, $restarted
    Add-Content -LiteralPath $logFile -Value $line
    Write-Host ("[{0}] siker={1} idő={2} s méret={3} bájt" -f (Get-Date -Format 'HH:mm:ss'), $ok, $seconds, $bytes)

    Start-Sleep -Seconds $IntervalSec
}
