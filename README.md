# Xavier Pickerbot Mini

## Gyorsindítás (bemutatóoldal)

Nyiss egy PowerShell-ablakot, és másold be ezt:

```powershell
cd C:\Users\david\Github\xavier-pickerbot
powershell -ExecutionPolicy Bypass -File .\scripts\start-demo-view.ps1
```

Ez megnyitja az oldalt: `http://127.0.0.1:8902/scripts/control_panel.html`

Leállításhoz:

```powershell
cd C:\Users\david\Github\xavier-pickerbot
powershell -ExecutionPolicy Bypass -File .\scripts\stop-demo-view.ps1
```

Egyéb kapcsolók: `-NoBrowser` (nem nyit böngészőablakot), `-DashboardOnly` (a teljes műszaki szenzornézetet nyitja meg a bázisvezérlős oldal helyett).

**2026-09-19 karfigyelmeztetés:** a fizikai joystickkel a talp fölötti fel-le ízület végállásnál daráló hangot és sípolást ad, utána rendellenesen mozog. A karon további mozgáspróbát ne végezz, amíg áramtalanítva át nem vizsgálták. A webes karvezérlés továbbra is szimuláció. A mérések és a gyári leállítási parancs kockázata: [docs/08-kezi-vezerles.md](docs/08-kezi-vezerles.md).

**Wheeltec gyártmányú, "Xavier Pickerbot Mini" néven értékesített oktatási robot** — mecanum kerekes alváz + 4 tengelyű robotkar, NVIDIA Jetson Xavier NX fedélzeti számítógéppel, LiDAR-ral és Orbbec Astra RGBD mélységkamerával.

Ez a Xavier Pickerbot Mini önálló repója: a robot szoftvere, indítófájljai és magyar nyelvű dokumentációja itt található. A Unitree Go2 külön projektben van.

**Jelenlegi laptopos felület:** a `scripts/start-demo-view.ps1` a helyi `http://127.0.0.1:8902/scripts/control_panel.html` oldalt nyitja meg. Ez EGYETLEN oldal: a C70 és hátsó kamerák, a valódi `/map`, az IR-panel, a LiDAR felülnézet, a 3D pontfelhő és a bázisvezérlés is itt van (a korábbi külön `dashboard.html` 2026-09-24-én megszűnt, minden funkciója átkerült ide). A roboton automatikusan futó 8901-es weboldal egy korábban telepített változat; a repó HTML-fájljai nem kerülnek oda pusztán a Git commit vagy push hatására. A webes megállítás nem helyettesíti a fizikai vészleállítót, a kar panelje továbbra is csak szimuláció.

**2026-09-21:** a térkép újrakezdése gombot a felhasználó kipróbálta. Az USB Wi-Fi bizonytalan kapcsolata miatt a robot beépített Intel Wi-Fi-jét a TP-Link routerhez kapcsoltuk. Kontrollált, lekapcsolt Ethernet és USB Wi-Fi mellett a robot `.50` címén SSH, valamint a bemutatóoldalon kamera és kezdetben változó térkép működött. A próba végén az Ethernet visszaállt, a beépített Wi-Fi csatlakozva maradt. Hosszabb ellenőrzéskor a `/map` új üzenetei megszűntek, ezt külön kell kivizsgálni. Valódi kábelkihúzás és kábel nélküli újraindítás még nincs igazolva. Részletek: [munkamenet-átadás](docs/11-munkamenet-atadas.md), [hálózat](docs/09-robot-halozat.md).

**Egyetlen fejlesztési felület:** a `scripts/control_panel.html` a Kutatók Éjszakája bemutatóoldala, ez tartalmaz mindent (kamerák, térkép, IR, LiDAR, 3D pontfelhő, bázis+kar vezérlés). A korábbi külön `scripts/dashboard.html` 2026-09-24-én megszűnt. Az aktuális reboot utáni állapotot a [munkamenet-átadás](docs/11-munkamenet-atadas.md) tartalmazza.

## Tartalomjegyzék

- [docs/00-hozzaferes.md](docs/00-hozzaferes.md) — hálózat, SSH, hogyan köss rá egy laptopot
- [docs/01-hogyan-elesztettuk-fel.md](docs/01-hogyan-elesztettuk-fel.md) — a robot állapota első bekapcsoláskor, és milyen hibákon vittük át élő állapotba
- [docs/02-hardver-es-rendszer.md](docs/02-hardver-es-rendszer.md) — Jetson platform, OS, ROS, lemezállapot
- [docs/03-erzekelok-aktuatorok.md](docs/03-erzekelok-aktuatorok.md) — kamerák, LiDAR, kar — topicok, mért adatok, driver-korlátok
- [docs/04-gyari-szoftver.md](docs/04-gyari-szoftver.md) — mi van a lemezen gyárilag, mit használunk belőle és mit nem
- [docs/05-sajat-projekt-iranyitopult.md](docs/05-sajat-projekt-iranyitopult.md) — **saját projekt #1**: élő webes irányítópult (kamerák + LiDAR + 3D point cloud)
- [docs/06-sajat-projekt-akademia.md](docs/06-sajat-projekt-akademia.md) — **saját projekt #2**: Pickerbot Akadémia — oktatási robotika-platform terve + autonóm generáló pipeline
- [docs/07-ismert-hibak.md](docs/07-ismert-hibak.md) — hibajelenség → ok → javítás táblázat, drágán megszerzett tudás
- [docs/08-kezi-vezerles.md](docs/08-kezi-vezerles.md) — **saját projekt #3**: kézi vezérlés (bázis-drive valós-képes ÉLESÍTÉS mögött, kar MOCK-ONLY); a `/cmd_vel` 2026-09-18-án élőben megerősítve
- [docs/10-bemutato-terkep.md](docs/10-bemutato-terkep.md) — a C70 kamera + valódi `/map` bemutató állapota és ellenőrzési sorrendje
- [docs/11-munkamenet-atadas.md](docs/11-munkamenet-atadas.md) — az aktuális állapot és a következő fejlesztőnek szóló átadás
- [docs/12-szenzor-inditasi-sorrend.md](docs/12-szenzor-inditasi-sorrend.md) — reboot utáni kamera/LiDAR/SLAM indítási sorrend és helyreállítás
- [docs/13-kar-es-gripper-vezerles.md](docs/13-kar-es-gripper-vezerles.md) — gyári parancsformátum, gripperskála, gombos modell és az élő bekapcsolás feltételei
- [docs/09-robot-halozat.md](docs/09-robot-halozat.md) — **a közös robot-hálózat** (2026-09-18): gateway PC + TP-Link router, IP-kiosztás, elérés, hibaelhárítás
- [scripts/](scripts/) — a ténylegesen használt kapcsolódó/indító szkriptek, másolható egy az egyben
- [docker/sensors/](docker/sensors/) — a C70 kamera és a csak helyben elérhető videófolyam Docker-indítása
- [docker/lidar/](docker/lidar/) és [docker/slam/](docker/slam/) — a LiDAR és a külön gmapping Docker-indítása
- [inventory.html](inventory.html) — vizuális szoftver-/tárhely-leltár a robot lemezéről
- [pickerbot-akademia-terv.html](pickerbot-akademia-terv.html) — a teljes Akadémia-terv, 11 architektúra-ábrával

## Gyors infó

| | |
|---|---|
| Modell | Wheeltec "Xavier Pickerbot Mini" (mecanum alváz + 4 DOF kar) |
| Fedélzeti gép | NVIDIA Jetson Xavier NX, JetPack/L4T 35.6.1 |
| OS | Ubuntu 20.04.6 LTS |
| ROS | Noetic (ROS 1, catkin), Python 3.8.10, CUDA 11.4 |
| IP | `192.168.123.50` (ROS-cím Etherneten vagy a beépített Wi-Fi-n); `192.168.123.52` a beépített Wi-Fi saját címe. A régi `192.168.0.100` hotspotprofil mentve maradt, de nem aktív. Lásd [docs/09-robot-halozat.md](docs/09-robot-halozat.md). |
| SSH | kulcsos, jelszó nélkül — `wheeltec@192.168.123.50`, kulcs: `~/.ssh/pickerbot_mini` |
| Sudo jelszó | `dongguan` (gyári alapértelmezett — ugyanaz, mint a Wi-Fi hotspot jelszava) |
| Státusz | élő, tesztelt irányítópult 2026-08-25 óta; kézi vezérlés élőben megerősítve 2026-09-18; oktatási platform terve kész, generálása folyamatban |
| Robotoldali, korábban telepített weboldal | `http://192.168.123.50:8901/control_panel.html` — automatikusan indul bekapcsoláskor, de a repó új kamera-/térképfelületét még nem tartalmazza |

## Kolléga-teszteléshez: mindent automatikusan indít a robot

**2026-09-18 óta:** a robot bekapcsolásakor a három alap systemd-szolgáltatás magától elindul. A roboton lévő régi vezérlőpult SSH nélkül elérhető a `http://192.168.123.50:8901/control_panel.html` címen. A repó aktuális C70- és térképes felületéhez a laptopon futó `scripts/start-demo-view.ps1` indító kell, amíg az új weboldal nincs a robotra telepítve.

Roboton futó systemd service-ek (`sudo systemctl status <név>` az ellenőrzéshez):
- `pickerbot-bringup` — `turn_on_wheeltec_robot.launch` (bázis-driver, `/cmd_vel`, `/arm_cmd`, `/odom`, `/imu`, `/PowerVoltage`)
- `pickerbot-rosbridge` — `rosbridge_websocket` (9090-es port, ettől függ a bringup-tól)
- `pickerbot-webui` — a `pickerbot_web_ui/` mappát szolgálja ki 8901-en (`control_panel.html`, `dashboard.html`)

Mindhárom `enable`-ölve van, `Restart=on-failure`-ral — összeomlás után maguktól újraindulnak.

**2026-09-18 korábbi, helyreállítás előtti mérés:** a 8901-es vezérlőpult és a 9090-es rosbridge elérhető volt, de a `/PowerVoltage` nem adott értéket, és a `/scan`, `/usb_cam/image_raw`, `/map` témáknak nem volt publikálója. A 8080-as kamera-stream port sem válaszolt. Az új webes térképpanel a `/map` hiányát jelzi; nem rajzol a nyers `/scan`-ből ál-térképet.

**2026-09-18, reboot után is ellenőrzött helyreállítás:** az árva bringup és a systemd-példány ütközése megszűnt, a szolgáltatás a helyes `mini_mec_moveit_four` modellt használja. Az első rebootpróba egy további indulási versenyt fedett fel: a rosbridge saját ROS mastert próbált indítani, mielőtt a bringup mastere elkészült. A rosbridge most megvárja a `/run_id` paramétert. A második reboot után pontosan egy bringup fut, a `/wheeltec_robot` válaszol, az odometria és az IMU friss, a feszültség 23,33 V körüli. Mindhárom `pickerbot-*` szolgáltatás aktív és engedélyezett. A kamera, a LiDAR és a `/map` még nem fut, és a helyi weboldal-módosítások nincsenek a roboton. A két konfigurációs fájl a [systemd/](systemd/) mappában, részletek: [docs/10-bemutato-terkep.md](docs/10-bemutato-terkep.md).

**2026-09-19, a szenzor-helyreállítás első szakasza:** a C70 kamera külön Docker-konténerben publikálta a `/usb_cam/image_raw` témát, mérve kb. 15 kép/s sebességgel. A webes videó csak a robot `127.0.0.1:8080` címén érhető el; a laptop [scripts/start-demo-view.ps1](scripts/start-demo-view.ps1) szkriptje SSH-alagúton át nyitja meg a helyi irányítópultot. A robot 8901-es, korábban telepített weboldala még nem tartalmazza az új térképpanelt. Ebben a szakaszban a `/scan` és `/map` még nem futott; részletek: [docs/10-bemutato-terkep.md](docs/10-bemutato-terkep.md).

**Ugyanazon a napon, későbbi frissítés:** a LiDAR és a gmapping is külön Docker-konténerből fut. A `/scan` kb. 12 Hz-cel érkezik, a `/map` élő, 5 cm-es foglaltsági rácsot publikál. A négy új konténer és a három korábbi systemd-szolgáltatás együttesen fut; fizikai mozgáspróba és rebootpróba ezekkel a konténerekkel még hátravan. A helyi dashboardon a C70 képe és a valódi `/map` panel egyszerre érhető el; részletek: [docs/10-bemutato-terkep.md](docs/10-bemutato-terkep.md).

**2026-09-23, szenzorindítási hiba megoldva és tiszta reboot után igazolva:** rebootkor a C70, a LiDAR és a SLAM Docker-konténere korábban a valódi ROS master előtt indult, ezért futó folyamat mellett sem regisztrált a `/usb_cam/image_raw`, `/scan` és `/map`. A kamera systemd-egysége szintén túl korán indulhatott. Emellett az Astra és a C70 ugyanazon az USB 2.0 buszon van; a C70 tömörítetlen YUYV módja mellett az Astra színes képe nem adott képkockát. Telepítve lett a ROS masterre váró kameraegység, a sorrendi `pickerbot-sensors-recover` egység és a C70 MJPEG beállítása. Tiszta robot-reboot után az `/odom`, mindkét Astra kép, a C70, a `/scan` és a `/map` is friss adatot adott; mind az öt systemd-szolgáltatás aktív. Részletek: [docs/12-szenzor-inditasi-sorrend.md](docs/12-szenzor-inditasi-sorrend.md).

## ⚠️ Mielőtt hozzányúlnál

- **USB-C a Jetsonon adatport, nem tápbemenet.** Csak a barrel jack (19V) vagy a robot saját akkuja indítja el.
- **Az `/camera/toggle_ir` service hívása összeomlasztja a kameradrivert** és USB-szinten beragasztja az eszközt — lásd [docs/07-ismert-hibak.md](docs/07-ismert-hibak.md).
- A gyári lemezen 5 alváz-kar kombináció csomagjai vannak egy image-ben; a mi példányunkhoz **csak a `mini_mec_four_arm*` csomagok relevánsak** — a többihez generált kód ne nyúljon, ne is hivatkozzon rájuk.
- **2026-09-18 élő teszt: `/cmd_vel` és `/arm_cmd` megerősítve, szoftverlánc (soros port, STM32, IMU/odom 20Hz) egészséges.** Ha mégsem mozog a bázis — se webről, se fizikai joystickről —, az hardveres ok (E-stop gomb, külön motor-tápkapcsoló, alacsony akkufeszültség), nem szoftverhiba. Lásd [docs/08-kezi-vezerles.md](docs/08-kezi-vezerles.md) diagnosztika szakaszát. **2026-09-23:** a gyári forrásból igazolt gripperskála `0 = nyitva`, `100 = zárva`; az élő karvezérlés továbbra is zárolt, mert nincs mért karpozíció, és a korábbi daráló/sípoló ízülethiba nincs fizikailag kivizsgálva. A webes abszolút csúszkák helyett korlátozott, kis lépéses gombos szimuláció készült.

## Licenc / szerzőség

Sári Bence (NeonPC / Neumann Robotics), 2026.
