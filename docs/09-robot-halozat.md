# A közös robot-hálózat (2026-09-21)

**Friss állapot (2026-09-21):** a Pickerbot beépített Intel Wi-Fi-je (`wlan0`) kliensként a `TP-Link_A426` hálózaton van, címe `192.168.123.52/24`. A régi robot-hotspot profil mentve maradt, de nem indul automatikusan. Az USB-s TP-Link adapter (`wlan1`) profilja tartalék; a legutóbbi ellenőrzéskor le volt kapcsolódva. A [failover-szkript](../scripts/robot-wifi-failover.sh) az Ethernet kiesésekor a robot ROS-címét (`192.168.123.50/32`) elsősorban a beépített Wi-Fi-re, ennek hiányában az USB Wi-Fi-re teszi. Ethernet visszatérésekor leveszi az alias címet. A jelszó a robot védett NetworkManager-profiljaiban van, a Git repóban nincs. A kontrollált próba és a korlátok a [munkamenet-átadásban](11-munkamenet-atadas.md) szerepelnek.

Egyetlen `192.168.123.0/24` hálón van minden: a netet adó gateway PC, a Unitree Go2, a Xavier Pickerbot Mini és a fejlesztő laptopok. Bárki, aki a routerre csatlakozik (Wi-Fi vagy kábel), internetet kap, és látja mindkét robotot.

Az alhálót a Go2 határozta meg: a Go2 gyárilag fix `192.168.123.x` címeket használ, és `192.168.123.1`-et vár átjárónak. Ezért a hálózat többi része igazodott hozzá, nem fordítva.

## Topológia

```
      belső intézményi háló (eduroam, Wi-Fi)
                      │
          ┌───────────┴────────────┐
          │  Gateway PC (Windows)  │   Wi-Fi: 10.1.18.255 (DHCP, változhat)
          │  DESKTOP-GUO1M82       │   "Ethernet 2": 192.168.123.1/24 (fix)
          │  WinNAT "RobotNAT"     │   NAT: 192.168.123.0/24 → Wi-Fi
          └───────────┬────────────┘
                      │ kábel → router 3-as LAN port (sárga)
          ┌───────────┴────────────┐
          │  TP-Link TL-WR940N     │   Access Point mód, 192.168.123.2
          │  DHCP .100–.149        │   gateway .1, DNS 8.8.8.8
          └──┬─────────┬────────┬──┘
             │ LAN     │ LAN    │ Wi-Fi
         Go2 robot  Pickerbot  laptopok / telefonok
         .18 / .20    .50       .100–.149 (DHCP)
```

A router WAN (kék) portja **nincs használva** — AP módban a router csak switch + Wi-Fi hozzáférési pont, a NAT-ot a gateway PC végzi.

## IP-kiosztás

| IP | Eszköz | Mód |
|---|---|---|
| `192.168.123.1` | Gateway PC, "Ethernet 2" (átjáró + NAT) | fix |
| `192.168.123.2` | TP-Link TL-WR940N (admin felület) | fix |
| `192.168.123.18` | Go2 — fedélzeti Jetson (SSH 22, web 80, `mc_sensor_hub` 9101) | fix, gyári |
| `192.168.123.20` | Go2 — Hesai LiDAR ("Pandar Console" web a 80-as porton) | fix, gyári |
| `192.168.123.50` | Xavier Pickerbot Mini — kábelen `eth0`, annak kiesésekor `wlan0`, majd `wlan1` alias | fix |
| `192.168.123.51` | Xavier Pickerbot Mini — TP-Link USB Wi-Fi (`wlan1`) | fix |
| `192.168.123.52` | Xavier Pickerbot Mini — beépített Intel Wi-Fi (`wlan0`) | fix |
| `192.168.123.99` | fejlesztő laptop Ethernet (kézi, ha kábellel jössz) | fix |
| `192.168.123.100`–`.149` | Wi-Fi / kábeles kliensek | DHCP a routertől |

**Szabad fix címnek:** `.3`–`.17`, `.21`–`.49`, `.53`–`.98`, `.150`–`.254`. Új fix eszközt ide tegyél, és írd be ebbe a táblázatba. A Go2 gyári belső címeit (`.18`, `.20`, és a Unitree-doksi szerinti többit, pl. `.161`) ne oszd ki másnak.

## Csatlakozás

### Wi-Fi

- SSID: `TP-Link_A426`. A korábban dokumentált gyári jelszó már nem érvényes; a jelenlegi jelszót a router tulajdonosától kérd. Ne tedd a Git repóba.
- Automatikusan kapsz `192.168.123.1xx` címet, átjáró `.1`, DNS `8.8.8.8` — azonnal van internet.

### Kábel

Bármelyik szabad sárga LAN port a routeren. DHCP-vel ugyanúgy kapsz címet, vagy kézzel: `192.168.123.99/24`, átjáró `192.168.123.1`.

### Belépés az eszközökre

```bash
# Pickerbot Mini (kulcsos, jelszó nélkül; sudo: dongguan)
ssh -i ~/.ssh/pickerbot_mini wheeltec@192.168.123.50

# Gateway PC (kulcsos; felhasználónévben szóköz van, idézőjel kell!)
ssh -i ~/.ssh/id_ed25519_neonpc "gaming pc@192.168.123.1"
# ugyanez az intézményi hálóról (a Wi-Fi címe DHCP, változhat):
ssh -i ~/.ssh/id_ed25519_neonpc "gaming pc@10.1.18.255"
```

- TP-Link admin: `http://192.168.123.2` (jelszót a router gazdája tudja).
- Go2: lásd a fő repó dokumentációját — a natív rendszerhez nem nyúlunk, csak Dockerből.

## A gateway PC beállításai

- Windows 11 Pro, hostname `DESKTOP-GUO1M82`, felhasználó `gaming pc`.
- **Wi-Fi** → intézményi háló (eduroam), DHCP.
- **"Ethernet 2"** → router, fix `192.168.123.1/24`, átjáró nélkül, hálózati profil: *Private*.
- **NAT: WinNAT, nem ICS.**
  ```powershell
  New-NetNat -Name RobotNAT -InternalIPInterfaceAddressPrefix 192.168.123.0/24
  ```
  - Az ICS (Internetkapcsolat-megosztás) **ki van kapcsolva**: saját DHCP-t futtatna `192.168.137.x`-en, ami ütközik a robotok fix címeivel.
  - A `New-NetNat` Windows 11 Pro-n csak **teljes Hyper-V** mellett működik (`dism /online /enable-feature /featurename:Microsoft-Hyper-V /all`, újraindítás). Csak a "Containers" funkcióval `Invalid class` hibát dob.
- Tűzfal: `sshd-in-any` (TCP 22, minden profil), `robotnet-icmp-in` (ping a `192.168.123.0/24`-ről).
- OpenSSH Server: pendrive-os telepítő a NeonPC repóban (`engineering/ssh-setup-pendrive/RUN_ME.bat`).

**Ha a gateway PC ki van kapcsolva, a hálón nincs internet**, de a robotok és laptopok egymást továbbra is látják (a router switch-ként működik).

## A router (TP-Link TL-WR940N) beállításai

| Menü | Érték |
|---|---|
| Working Mode | **Access Point** |
| Network → LAN | IP `192.168.123.2`, maszk `255.255.255.0` |
| DHCP Server | Enable, `192.168.123.100` – `192.168.123.149` |
| DHCP → Default Gateway | **`192.168.123.1`** (üresen hagyva a router saját magát, a `.2`-t osztaná ki → nincs internet) |
| DHCP → Primary DNS | `8.8.8.8` |
| Wireless Security | WPA2; aktuális jelszó a router tulajdonosánál |

## A Pickerbot hálózati beállítása

**Frissítés a 2026-09-18-i fizikai incidens után:** a beépített LAN-port megsérült. Az USB-LAN adapter átvette az `eth0` nevet, a régi port `eth1` és `NO-CARRIER` volt a dokumentált méréskor. Az alábbi táblázat a korábbi beállítás pillanatképe; új csatlakozás után `ip -br addr` és `ip -br link` kimenettel ellenőrizd, hogy az aktív adapteren van-e a `.50` cím.

A Pickerbot hálózati interfészeit NetworkManager kezeli:

| Interfész | NM profil | Cím | Szerep |
|---|---|---|---|
| `eth0` | `Profile 1` | `192.168.123.50/24`, gw `192.168.123.1`, DNS `8.8.8.8 1.1.1.1` | közös robot-háló |
| `wlan0` | `pickerbot-onboard-wifi` | `192.168.123.52/24`; kábel nélkül további `.50/32` alias | beépített Intel 8265, routerkliens |
| `wlan1` | `pickerbot-robot-wifi` | `192.168.123.51/24`; csak `wlan0` kiesésekor `.50/32` alias | TP-Link USB adapter, tartalék |

A beépített kliensprofil neve `pickerbot-onboard-wifi`, automatikusan kapcsolódik. A korábbi `WHEELTEC_OrinSuper_Noetic_JP515` hotspot-profil megmaradt, de automatikus indulása ki van kapcsolva. A két mód ugyanazt a `wlan0` rádiót használja, ezért a saját hotspot kliensmód közben nem sugároz. Helyben szükség esetén `sudo nmcli connection up WHEELTEC_OrinSuper_Noetic_JP515 ifname wlan0` paranccsal visszakapcsolható; ezzel megszűnik a TP-Link klienskapcsolat. A `wlan1` profilja a roboton `/etc/NetworkManager/system-connections/pickerbot-robot-wifi.nmconnection` helyen van, `root:root`, `0600` jogosultsággal. A jelszó a védett profilokban van. A Wi-Fi útvonal-metrika 150 (`wlan0`), illetve 200 (`wlan1`), így bedugott kábelnél az Ethernet az elsődleges. A `192.168.123.50` ROS-cím az aktív kapcsolaton marad; nem kell átírni a ROS node-ok és a bemutatóoldal címét. A failover-szkript repóbeli forrása [robot-wifi-failover.sh](../scripts/robot-wifi-failover.sh), telepített példánya `/etc/NetworkManager/dispatcher.d/90-pickerbot-wifi-failover`.

Ellenőrzés a roboton: `nmcli -f DEVICE,STATE,CONNECTION dev status`, `ip -br addr show eth0`, `ip -br addr show wlan0`, `ip route get <laptop-cím> from 192.168.123.50`. Kábel nélkül a legutóbbi parancsban `dev wlan0` kell szerepeljen, ha a beépített kapcsolat aktív. Ha a videóalagút a kábel kihúzásakor megszakad, a laptopon futtasd újra `scripts/start-demo-view.ps1 -NoBrowser`; az indító egy valódi kameraképpel ellenőrzi a meglévő alagutat, és szükség esetén újat nyit. A böngészőben a bemutatóoldal újratöltése a ROS WebSocketet is újraköti. A kábeles kapcsolat visszaállítása: `sudo nmcli device connect eth0`.

ROS a `~/.bashrc`-ben (régi értékek kommentben, mentés: `~/.bashrc.bak-20260918`):

```bash
export ROS_MASTER_URI=http://192.168.123.50:11311
export ROS_HOSTNAME=192.168.123.50
```

Ha a laptopról ROS-t használsz a robot felé: `ROS_MASTER_URI=http://192.168.123.50:11311`, `ROS_IP=<a laptop 192.168.123.x címe>`.

**Következmény:** a robot régi saját hotspotja jelenleg nincs bekapcsolva. Ha kézzel visszakapcsolod, a rá csatlakozó gép a ROS mastert továbbra sem éri el alapból (csak SSH-t `192.168.0.100`-on), mert a ROS a `.50` címet hirdeti.

### A hiba, amit javítottunk ("rogue DHCP")

Eredetileg az `eth0` és a `wlan0` is `192.168.0.100`-at kapott. A hotspot ("shared" mód) által indított `dnsmasq` cím alapján figyel (`--listen-address=192.168.0.100`), így **a kábelen is DHCP-t osztott**: a TP-Link Wi-Fijén lévő gépek `192.168.0.x` címet és `192.168.0.100` átjárót kaptak, internet nélkül. Ugyanemiatt a routeren keresztül a robot sem volt elérhető (a válaszok rossz interfészen mentek ki).

Javítás — `eth0` átköltöztetése a robot-hálóra, a hotspot átjáró-mezőjének törlése (a jelszót a futtató gépeli be):

```bash
ssh -t -i ~/.ssh/pickerbot_mini wheeltec@192.168.0.100 "sudo -v && sudo nmcli con mod 'Profile 1' ipv4.addresses 192.168.123.50/24 ipv4.gateway 192.168.123.1 ipv4.dns '8.8.8.8 1.1.1.1' && sudo nmcli con mod WHEELTEC_OrinSuper_Noetic_JP515 ipv4.gateway '' && echo MODOSITVA && (sudo setsid nohup sh -c 'sleep 2; nmcli con up \"Profile 1\"' >/dev/null 2>&1 &) ; sleep 1"
```

Buktató: ha az egész `&&`-láncot a végén `&`-tel háttérbe küldöd, az SSH bezárul, mielőtt a `sudo` megkapná a jelszót, és semmi nem módosul. Ezért van előbb `sudo -v`, és csak az `nmcli con up` fut háttérben (különben a címváltás közben elvágná a saját SSH-kapcsolatát).

**Szabály:** a Pickerbot `eth0`-ja soha ne legyen ugyanabban az alhálóban, mint a hotspot — különben a DHCP újra kiszivárog a kábelre.

## Hibaelhárítás

| Jelenség | Ok | Megoldás |
|---|---|---|
| Wi-Fi-n `192.168.0.x` címet kapsz | valami (Pickerbot hotspot) DHCP-t oszt a kábelen | `ipconfig /all` → "DHCP Server" mutatja, ki osztotta; lásd fent |
| Van `192.168.123.x` cím, nincs net, átjáró `.2` | a router DHCP-jében üres a Default Gateway | router: DHCP → Default Gateway = `192.168.123.1` |
| Semmin nincs net, egymást látják | gateway PC ki van kapcsolva / Wi-Fi-je leesett / NAT eltűnt | gateway PC-n: `Get-NetNat`, `ping 1.1.1.1` |
| A gateway PC nem pingelhető | tűzfal | `robotnet-icmp-in` szabály (fent) |
| `ssh` "Host key verification failed" egy címre | ugyanazon IP-n korábban más eszköz volt | `ssh-keygen -R <ip>`, majd újra |
| A router nem érhető el `.2`-n | AP módban néha DHCP-címet vesz fel | nézd a gateway PC ARP-táblájában a router MAC-jét: `84-D8-1B-F6-A4-26` |

Ellenőrzés a gateway PC-n, hogy tényleg rajta megy-e át a forgalom:

```powershell
Get-NetNatSession | Select InternalSourceAddress, ExternalDestinationAddress -First 10
```

## Ismert MAC-címek

| MAC | Eszköz |
|---|---|
| `9C-6B-00-C6-8F-73` | gateway PC, "Ethernet 2" |
| `84-D8-1B-F6-A4-26` | TP-Link TL-WR940N |
| `4C-BB-47-F0-1B-0A` | Go2 Jetson (NVIDIA OUI) |
| `EC-9F-0D-03-06-64` | Go2 Hesai LiDAR |
| `4C-BB-47-27-9C-B5` | Pickerbot Mini `eth0` (NVIDIA OUI) |
