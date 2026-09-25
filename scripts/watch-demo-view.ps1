# Videóalagút-őrző és mérőnapló a bemutatónézethez.
# Alapból 10 másodpercenként lekér egy C70- és egy hátsó RGB-pillanatképet a helyi alagúton át.
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
$logFile = Join-Path $env:TEMP 'pickerbot-demo-watch-v2.csv'
$errorLogFile = Join-Path $env:TEMP 'pickerbot-demo-watch-errors.log'
$probes = @(
    @{ Name = 'c70'; Url = 'http://127.0.0.1:8080/snapshot?topic=/usb_cam/image_raw&quality=55' },
    @{ Name = 'rgb'; Url = 'http://127.0.0.1:8080/snapshot?topic=/camera/rgb/image_raw&quality=55' }
)

if (-not (Test-Path -LiteralPath $starter)) {
    throw 'A start-demo-view.ps1 nem található.'
}
if (-not (Test-Path -LiteralPath $logFile)) {
    'ido,c70_siker,c70_masodperc,c70_bajt,rgb_siker,rgb_masodperc,rgb_bajt,ujrainditas' | Set-Content -LiteralPath $logFile -Encoding UTF8
}

Write-Host "Alagút-őrző fut. Napló: $logFile"
Write-Host 'Leállítás: Ctrl+C'

$fails = 0
while ($true) {
    $results = @{}
    foreach ($probe in $probes) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $ok = $false
        $bytes = 0
        try {
            $response = Invoke-WebRequest -Uri $probe.Url -UseBasicParsing -TimeoutSec $TimeoutSec
            if ($response.StatusCode -eq 200 -and $response.Headers['Content-Type'] -like 'image/jpeg*') {
                $ok = $true
                $bytes = $response.RawContentLength
            }
        } catch {
            $ok = $false
        }
        $stopwatch.Stop()
        $results[$probe.Name] = @{
            Ok = $ok
            Seconds = [math]::Round($stopwatch.Elapsed.TotalSeconds, 2)
            Bytes = $bytes
        }
    }

    $roundOk = $results.c70.Ok -and $results.rgb.Ok

    $restarted = 0
    if ($roundOk) {
        $fails = 0
    } else {
        $fails++
        if ($fails -ge $FailuresBeforeRestart) {
            Write-Host ("[{0}] Nincs kép {1} mérés óta, alagút újraindítása..." -f (Get-Date -Format 'HH:mm:ss'), $fails)
            try {
                $restartOutput = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $starter -NoBrowser 2>&1
                if ($LASTEXITCODE -ne 0) { throw ($restartOutput -join ' ') }
                $restarted = 1
            } catch {
                $restartError = $_.Exception.Message -replace '[\r\n]+', ' '
                Add-Content -LiteralPath $errorLogFile -Value ("{0} {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $restartError)
                Write-Host 'Az újraindítás hibával állt le, a következő körben újra próbálom.'
            }
            $fails = 0
        }
    }

    $line = '{0},{1},{2},{3},{4},{5},{6},{7}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
        [int]$results.c70.Ok, $results.c70.Seconds, $results.c70.Bytes,
        [int]$results.rgb.Ok, $results.rgb.Seconds, $results.rgb.Bytes, $restarted
    Add-Content -LiteralPath $logFile -Value $line
    Write-Host ("[{0}] C70={1} ({2} s), RGB={3} ({4} s), újraindítás={5}" -f
        (Get-Date -Format 'HH:mm:ss'), $results.c70.Ok, $results.c70.Seconds,
        $results.rgb.Ok, $results.rgb.Seconds, $restarted)

    Start-Sleep -Seconds $IntervalSec
}
