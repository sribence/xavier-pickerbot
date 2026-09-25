$ErrorActionPreference = 'Stop'
$stateFile = Join-Path $env:TEMP 'pickerbot-demo-view.json'
if (-not (Test-Path -LiteralPath $stateFile)) {
    Write-Host 'A bemutatónézet nem fut ezen a gépen.'
    exit 0
}
$state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
$watcherPid = if ($state.PSObject.Properties.Name -contains 'watcherPid') { $state.watcherPid } else { $null }
# Előbb az őrzőt állítjuk le, különben észlelhetné az alagút leállását, és azonnal újraindíthatná.
foreach ($entry in @(@($watcherPid, @('powershell', 'pwsh')), @($state.serverPid, @('python')), @($state.tunnelPid, @('ssh', 'plink')))) {
    if (-not $entry[0]) { continue }
    $process = Get-Process -Id $entry[0] -ErrorAction SilentlyContinue
    if ($process -and $process.ProcessName -in $entry[1]) {
        # A folyamat az ellenőrzés és a leállítás között magától is kiléphet; ilyenkor ez nem hiba.
        Stop-Process -Id ([int]$entry[0]) -Force -ErrorAction SilentlyContinue
    }
}
Remove-Item -LiteralPath $stateFile
$remaining = @()
foreach ($pidValue in @($watcherPid, $state.serverPid, $state.tunnelPid)) {
    if ($pidValue -and (Get-Process -Id $pidValue -ErrorAction SilentlyContinue)) { $remaining += [int]$pidValue }
}
if ($remaining.Count) {
    Write-Warning ("Néhány magasabb jogosultsággal indított helyi folyamat nem állítható le innen (PID: {0}). Az indító ezeket felismeri és újra használja." -f ($remaining -join ', '))
} else {
    Write-Host 'A helyi bemutatónézet leállt. A robot szolgáltatásai tovább futnak.'
}
