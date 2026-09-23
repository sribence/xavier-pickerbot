# Átadás: robot-oldali szenzor-instabilitás (LiDAR / C70 / hátsó RGB)

**Dátum:** 2026-09-23
**Státusz:** control_panel.html-ben lévő hibák JAVÍTVA és commitolva. A most leírt probléma **robot-infrastruktúra hiba**, nem a control_panel.html kódjában van — SSH-n, a robot systemd/launch konfigurációjában kell tovább vizsgálni.

---

## 1. Hozzáférés / környezet

- **Repo:** `C:\Users\david\Github\xavier-pickerbot` (Windows gép), fő fájl: `scripts/control_panel.html`
- **Robot SSH:** kulcs `$env:USERPROFILE\Documents\Codex\pickerbot-access\pickerbot_mini`, known_hosts ugyanott, host `wheeltec@192.168.123.50`
- **Sudo:** szükséges a robot service-einek kezeléséhez, **nincs jelszó nélküli sudo**. A jelszó dokumentálva van a repo `README.md`-jében ("Sudo jelszó" mező) — csak interaktív SSH-n (`ssh -t ...`) kérd be, soha ne írd parancsba nyíltan.
- **Demo-nézet indítása (Windows oldalon):** `scripts/start-demo-view.ps1` / `scripts/stop-demo-view.ps1` — SSH-alagutat épít (127.0.0.1:8080 → robot:8080, web_video_server-hez) és elindít egy helyi HTTP szervert (127.0.0.1:8902), ami a `control_panel.html`-t szolgálja ki. A böngésző közvetlenül a robot LAN-IP-jére (`ws://192.168.123.50:9090`) csatlakozik rosbridge-hez, NEM az alagúton keresztül.
- Robot: WHEELTEC Jetson-alapú platform (Ubuntu, systemd), ROS1 Noetic, `car_mode:=mini_mec_moveit_four`.

## 2. Mai session: control_panel.html javítások (LEZÁRVA, működnek)

Mind commitolva, validálva (div-egyensúly, duplikált ID-k, `node --check`, CRLF-megőrzés):

1. `[hidden]` CSS override globális hiba javítva (`!important` szabály).
2. A nagy nézet fejléce (`#bigHead`) áthelyezve a kép aljára.
3. IR csempe eltávolítva (felhasználói kérésre — a driver korábban élesben FATAL hibával összeomlott rajta).
4. A/D irányítás megcserélve (élő tesztben A jobbra, D balra vitte a robotot — javítva).
5. **Mélység-kisképe (`depthCanvasThumb`) `hidden`-never-cleared hiba javítva.**
6. **Hátsó RGB nagy kép never-suspended hiba javítva** (`refreshRgbFeed()` — mostantól szimmetrikusan felfüggeszti a nem-aktív nézet MJPEG-kapcsolatát, nem csak a kisképét).
7. **`lidarGeom` TDZ (temporal dead zone) versenyhelyzet javítva**: a 3D Three.js-objektumok (pontfelhő, LiDAR-pontok) létrehozása mostantól garantáltan megelőzi a `/scan` és `/camera/depth/points` feliratkozást a forráskódban, hogy egy gyors LAN-üzenet sose érhessen oda hamarabb, mint hogy a rá hivatkozó JS-objektumok elkészülnek.
8. **PointCloud2 hálózati terhelés csökkentve**: `throttle_rate` 400 → 2000 ms (a nyers üzenet ~4,9 MB/üzenet, ez erősen versenyzett a kamera-videóval a WiFi-n). Emellett bekerült egy `PC_CLOUD_ENABLED = false` kapcsoló, ami jelenleg TELJESEN kikapcsolja a pontfelhő-feliratkozást (élő sávszélesség-teszt céljából, a felhasználó kérésére) — könnyen visszakapcsolható `true`-ra.
9. **KRITIKUS: WebGL-renderelő létrehozási hiba elleni védelem.** Élő tesztben elkaptunk egy `Uncaught Error: Error creating WebGL context`-et a Three.js `WebGLRenderer` létrehozásánál (böngésző-oldali WebGL-kontextus-kimerülés sok újratöltés után). Mivel ez a szkript LEGFELSŐ SZINTJÉN történt (nem eseménykezelőben), egy el nem kapott hiba itt **megállította volna a teljes szkript hátralévő részének lefutását** — ez magyarázta, hogy egy WebGL-hiba esetén nemcsak a 3D nézet, hanem a logolás, az adatkiírás és a vezérlés bekötése is egyszerre eltűnt. Mostantól ez a rész `try/catch`-be van csomagolva egy `pc3dAvailable` flaggel — ha a WebGL elbukik, csak a 3D nézet marad üres, minden más függetlenül tovább működik. Ez élő böngészőben (a felhasználó gépén, teljes böngésző-újraindítás után) igazoltan megoldotta a "minden eltűnik" tünetet.

**Nyitva maradt, control_panel.html-hez kötődő tételek (nem foglalkoztunk vele ma):**
- Az ÉLESÍTÉS gomb nem-reagálásának eredeti panasza — nincs megerősítve/diagnosztizálva rendesen (a felhasználó nem válaszolt a "not-allowed kurzor mutatkozik-e" kérdésre, aztán más hibákra terelődött a fókusz).
- A jobb oldali panel "összecsúszás" CSS-javítása (`.side-fixed > .panel, .side-scroll > .panel { flex:0 0 auto; min-height:auto; }`) egy korábbi rollback során elveszett, és azóta nem lett újra alkalmazva.
- A C70 periodikus-retry "unhide" versenyhelyzet-javítás szintén elveszett egy rollback során, nincs újra alkalmazva.
- `docs/11-munkamenet-atadas.md` frissítésre szorul a mai összes változással (rollback, IR-eltávolítás, A/D csere, a fenti 5 új javítás, és ez az egész robot-infra vizsgálat) — jelenleg csak a legkorábbi (`[hidden]` + C70 retry + bigHead) változásokig van dokumentálva.

## 3. A MOST NYITOTT probléma: robot-oldali szenzor-megbízhatóság

**Tünet:** minden `sudo reboot`/fizikai újraindítás UTÁN (USB-kábelek piszkálása nélkül, tisztán) konzisztensen csak **két** topic jön fel megbízhatóan:
- `/camera/depth/image_raw` — kb. 29,7 Hz
- `/odom` — kb. 20 Hz

Ezek **nem** jönnek fel magától:
- `/usb_cam/image_raw` (C70, elülső kamera)
- `/camera/rgb/image_raw` (hátsó Astra RGB szín-stream)
- `/scan` (LiDAR)
- `/map` (ez a `/scan` hiányának egyenes következménye — a gmapping-nek nincs bemenete, önmagában nem hibás)

### 3.1 Systemd-szolgáltatások (teljes lista lekérve: `systemctl list-units --type=service --all`)

Csak **4 db `pickerbot-*` service** létezik:

| Service | Mit indít | Állapot minden reboot után |
|---|---|---|
| `pickerbot-bringup.service` | `roslaunch turn_on_wheeltec_robot turn_on_wheeltec_robot.launch car_mode:=mini_mec_moveit_four` — base/motor (`wheeltec_robot_node` → `/odom`, `/imu`, `/PowerVoltage`), static TF-ek, joint_state_publisher, robot_pose_ekf | **Megbízható** (odom megy) |
| `pickerbot-camera.service` | `roslaunch turn_on_wheeltec_robot wheeltec_camera.launch` (`camera_mode=Astra_S` alapértelmezett) → `astra_camera_node` | **Részben megbízható** — a mélység mindig jön, a szín gyakran NEM (ld. 3.3) |
| `pickerbot-rosbridge.service` | rosbridge websocket (port 9090) | Megbízható |
| `pickerbot-webui.service` | `web_video_server` (port 8080) + control_panel HTTP kiszolgálás | Megbízható |

**Nincs önálló systemd service sem a LiDAR-ra, sem a C70-re.** Ez alá van húzva a teljes `systemctl list-units --all` kimenettel — egyik service neve sem tartalmazza a "lidar" vagy "usb_cam" szót.

### 3.2 LiDAR (`/scan`) — hol fut, mi a gyanú

- Folyamat: `/opt/pickerbot/bin/lslidar_driver_node` (M10_P típus, `_serial_port:=/dev/wheeltec_lidar`)
- **ROOT felhasználóként fut**, miközben minden más ROS-node `wheeltec` userként megy (pl. `wheeltec_robot_node`, `astra_camera_node`) — ez erős jel, hogy NEM a `pickerbot-bringup.service`-en belüli sima `<node>` tag indítja (az mind `wheeltec` userrel futna), hanem valami külön, emelt jogú mechanizmus: vagy egy `sudo`-előtaggal ellátott `<node>` a `turn_on_wheeltec_robot.launch` fájlon belül, vagy egy **udev-szabály**, ami a LiDAR USB-eszköz csatlakozásakor fut le (`/etc/udev/rules.d/` alatt érdemes keresni, pl. `RUN+="..."` mintára).
- Egy korábbi (nem-reboot, kézi restart utáni) állapotban a folyamat FUTOTT (CPU-t használt), de **nem szerepelt a `rosnode list`-ben** — vagyis árva volt, valószínűleg egy régebbi (már halott) ROS master `run_id`-jéhez próbált csatlakozni, mert a `pickerbot-bringup.service` minden restartkor **teljesen ÚJ ROS mastert hoz létre** (`auto-starting new master`, új `run_id` minden egyes indításkor — ez `roslaunch` alapviselkedése, ha nem talál élő mastert indításkor).
- **Nincs megtalálva, PONTOSAN mi indítja el.** Ez a legfontosabb következő lépés.

### 3.3 Hátsó Astra RGB szín-stream (`/camera/rgb/image_raw`) — USB-flakiness gyanú

- A `pickerbot-camera.service` node-log-jában (journalctl) KONZISZTENSEN megjelenik induláskor:
  ```
  [WARN] Infrared and Color streams are enabled. Infrared stream will be disabled.
  [WARN] No color sensor found or transition is invalid , setting translation to 0
  ```
- Néha (kb. az esetek felében, megfigyelés alapján) a driver EZUTÁN mégis folytatja, és sikeresen jelenti: `Start color stream.` → `color is started` — vagyis a driver AZT HISZI, elindult a szín-stream.
- **DE ekkor is előfordul, hogy a `rostopic hz /camera/rgb/image_raw` "no new messages"-t ad** — azaz a driver azt hiszi, streamel, de ténylegesen NEM jön adat a topicra. Ez a mintázat (registrál, de nincs valódi adatfolyam) klasszikus USB-szintű/hardveres flakiness jele, nem szoftverhiba.
- Ez konzisztens a kódban korábban is dokumentált IR-szenzor-crash problémával (`astra_camera` driver ismerten instabil a mélységen kívüli sub-streamekkel, korábban FATAL crash-t is produkált IR-en, ami USB-resetet igényelt).
- **Egyszer sikerült élesben (kézi `roslaunch`-csal, systemd-n kívül) elindítani úgy, hogy TÉNYLEG jött adat is (29,6 Hz mérve)** — tehát a hardver KÉPES rá, csak nem megbízhatóan indul el minden alkalommal.

### 3.4 Amit ma kipróbáltunk, és mi lett belőle (kronológiai sorrendben — tanulságokkal)

1. **`rostopic hz` mindenre** — alap diagnosztikai eszköz egész délután, ez adta a legtöbb infót.
2. **Kézi `kill <PID>` az astra_camera_node-on**, majd kézi `nohup roslaunch turn_on_wheeltec_robot wheeltec_camera.launch &` — ⚠️ **EZT NE ISMÉTELD MEG.** A `pickerbot-camera.service` már felügyeli ugyanezt a node-ot; a kézi újraindítás összeütközött vele (`"[/image_transport] Reason: new node registered with same name"` hiba). Mindig `sudo systemctl restart pickerbot-camera.service`-et használj, soha ne indíts kézzel `roslaunch`-csal olyat, amit egy service már kezel.
3. **Teljes USB-kábelkiszedés-visszadugás** (a felhasználó nem tudta, melyik port melyik eszköz, ezért mindet kihúzta/visszadugta) — ez átmenetileg helyreállította a kamerát, **DE összeomlasztotta a motorvezérlő (`/wheeltec_robot`) node-ot is** (soros port megszakadt aktív kommunikáció közben, nem állt magától helyre — nincs respawn rá). ⚠️ Ha USB-t kell piszkálni, csak EGYENKÉNT, azonosítva előbb melyik eszköz melyik port (pl. `ls -la /dev/wheeltec_*` a stabil szimbolikus linkekért), és utána ellenőrizd MINDEN más topicot is, nem csak amelyiket javítani akartad.
4. **`sudo systemctl restart pickerbot-bringup.service pickerbot-camera.service` EGYSZERRE, egy parancsban** — ⚠️ **EZT SE ISMÉTELD MEG EGYSZERRE.** Mivel a bringup minden restartkor új ROS mastert hoz létre, az EGYIDEJŰ camera-restart abba a pillanatba eshet, amikor még nincs élő master → a camera roslaunch-a is megpróbál sajátot indítani → port-ütközés → `KeyboardInterrupt` → crash → systemd auto-restart (ez másodszorra sikerült, de ez szerencse volt, nem garantált). **Mindig egyenként, egymás UTÁN indítsd újra a service-eket, várva hogy az első stabilan felálljon** (pl. `rosnode list` ellenőrzéssel), mielőtt a másodikat újraindítanád.
5. **Teljes, tiszta robot-reboot** (`sudo reboot`, semmi kézi service-piszkálás utána) — ez az aktuális, "tiszta mérési" állapot: depth+odom megbízható, C70+RGB+scan(+map) megbízhatatlan. Ez a legjobb kiindulópont a további vizsgálathoz, mert nincs benne semmilyen kézi beavatkozás okozta torzítás.

### 3.5 PowerShell/SSH idézőjelezési csapdák (hasznos referencia a további munkához)

A mai session sok időt vesztegetett el idézőjelezési hibákkal SSH-n keresztüli távoli bash-parancsok küldésekor Windows PowerShellből. A **működő minta**:

```powershell
$key = Join-Path $env:USERPROFILE 'Documents\Codex\pickerbot-access\pickerbot_mini'
$knownHosts = Join-Path $env:USERPROFILE 'Documents\Codex\pickerbot-access\known_hosts'

ssh -i $key -o "UserKnownHostsFile=$knownHosts" -o StrictHostKeyChecking=yes wheeltec@192.168.123.50 `
    "bash -lc 'source /opt/ros/noetic/setup.bash; <parancsok pontosvesszővel>'"
```

Vagyis: **külső PowerShell DUPLA idézőjel**, **belső `bash -lc` EGYSZERES idézőjel**, sortörés backtick (`` ` ``) karakterrel a sor végén.

Csapdák, amikbe belefutottunk:
- `\"` **NEM** működik idézőjel-escapelésre PowerShell dupla-idézőjeles stringben — helyette backtick-idézőjel kell: `` `" ``. (`\"` PowerShellben nem escape-karakter, ettől esik szét a parancs "unexpected EOF" hibával.)
- `$valtozo` egy PowerShell dupla-idézőjeles stringen belül **interpolálódik**, MÉG AKKOR IS, ha te a bash oldalán szeretnéd ciklusváltozóként használni (pl. `for t in ...; do echo $t; done`) — PowerShell ilyenkor üresre cseréli, mielőtt bash egyáltalán látná. Védd backtickkel: `` `$t ``.
- `|` (pipe) egy `bash -lc '...'` stringen belül **valódi bash-pipe-ként** viselkedik, akkor is, ha te regex-alternációnak szántad (`grep -iE minta1|minta2` szétesik különálló, hibás parancsokra). Ha regex-alternáció kell, tedd bash-idézőjelbe: `grep -iE "minta1|minta2"` — de ez megint PowerShell-escapelést igényel a belső `"` miatt. Egyszerűbb: több különálló, egyszerű `grep -i` hívás.
- Sudo jelszót igénylő parancsokhoz `ssh -t ...` kell (pszeudo-terminál), különben "a terminal is required to read the password" hibát kapsz.

## 4. Javasolt következő lépések (a másik ágensnek)

1. **Derítsd ki pontosan, mi indítja a LiDAR-t és a C70-et.** Nézd át a `turn_on_wheeltec_robot.launch` teljes tartalmát (és minden `<include>`-olt fájlt) a `sudo`-előtaggal induló `<node>` tag-ekért; nézd meg az `/etc/udev/rules.d/` tartalmát LiDAR/kamera-vonatkozású szabályokért; nézd meg van-e `/etc/rc.local` tartalom (a `rc-local.service` maga inaktív volt, de érdemes megnézni a fájlt is) vagy cron-bejegyzés.
2. **Csinálj belőlük rendes systemd service-t** a 4 meglévő `pickerbot-*.service` mintájára (`/etc/systemd/system/` alatt), megfelelő `After=`/`Requires=` függőséggel a `pickerbot-bringup.service`-re (hogy biztosan a ROS master már fusson, mire ezek indulnak), és `Restart=on-failure` beállítással.
3. **Az Astra RGB szín-szenzor USB-flakiness-ét** érdemes mélyebben megvizsgálni (firmware/driver log, esetleg `dmesg` USB-hibákért közvetlenül a sikertelen induláskor) — lehet, hogy csak hardveres megoldás van rá (USB-hub/kábel csere), mint ahogy a korábbi IR-probléma is fizikai USB-resetet igényelt.
4. **Fegyelmezett service-kezelés**: soha ne indíts kézzel `roslaunch`-csal olyat, amit egy `pickerbot-*.service` már kezel; soha ne indíts újra egyszerre több, egymástól függő service-t egy parancsban — egyenként, ellenőrizve köztük.
5. **Miután a robot-oldali indítás stabil**, térjetek vissza a control_panel.html hátralévő nyitott tételeire (2. szakasz vége), és frissítsétek a `docs/11-munkamenet-atadas.md`-t a mai teljes eseménysorral.
