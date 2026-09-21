# Csak olvasó SLAM-diagnosztika a roboton. Nem indít újra semmit, mozgásparancsot nem küld.
# A robot SSH-jelszavát ebben az ablakban te írod be, ha kéri; a szkript nem tárolja.
# A teljes kimenet a repó gyökerében lévő slam-diagnosztika.txt fájlba kerül (ezt ne commitold).
$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$outFile = Join-Path $repoRoot 'slam-diagnosztika.txt'
$accessDir = Join-Path $env:USERPROFILE 'Documents\Codex\pickerbot-access'
$key = Join-Path $accessDir 'pickerbot_mini'
$knownHosts = Join-Path $accessDir 'known_hosts'

$sshArgs = @('-o', 'StrictHostKeyChecking=yes', '-o', "UserKnownHostsFile=$knownHosts")
$keyReadable = $false
if (Test-Path -LiteralPath $key) {
    try {
        $stream = [System.IO.File]::OpenRead($key)
        $stream.Dispose()
        $keyReadable = $true
    } catch { $keyReadable = $false }
}
if ($keyReadable) { $sshArgs += @('-i', $key) }
$sshArgs += 'wheeltec@192.168.123.50'
$sshArgs += 'bash -s'

# A parancsokat stdin-en küldjük, így a Windows nem rontja el az idézőjeleket és zárójeleket.
$remote = @'
source /opt/ros/noetic/setup.bash
source /home/wheeltec/wheeltec_robot/devel/setup.bash
echo "== ido"; date
echo "== wlan0"; iw dev wlan0 link; iw dev wlan0 get power_save
echo "== /scan hz (6 mp)"; timeout 6 rostopic hz /scan
echo "== /odom hz (6 mp)"; timeout 6 rostopic hz /odom
echo "== /imu hz (6 mp)"; timeout 6 rostopic hz /imu
echo "== /tf hz (6 mp)"; timeout 6 rostopic hz /tf
echo "== /map hz (10 mp)"; timeout 10 rostopic hz /map
'@
$remote = ($remote -replace "`r", "") + "`n"

$remote | & ssh.exe @sshArgs 2>&1 | Tee-Object -FilePath $outFile
Write-Host "ssh kilépési kód: $LASTEXITCODE"
Write-Host "Kimenet: $outFile"

# 2. rész: a Docker-adatokhoz sudo kell. Ezt a kimenetet csak a képernyőn látod; másold be nekem.
# A robot sudo-jelszavát itt te írod be, ha kéri.
Write-Host ''
Write-Host '== 2. rész: SLAM-konténer (sudo jelszó kellhet, te írd be) =='
$dockerArgs = $sshArgs[0..($sshArgs.Count - 2)]
& ssh.exe -t @dockerArgs 'sudo docker stats --no-stream pickerbot-slam; sudo docker logs --tail 150 pickerbot-slam 2>&1'
