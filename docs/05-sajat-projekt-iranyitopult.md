# Saját projekt #1 — élő webes irányítópult

**2026-08-25-én szenzorokkal tesztelve.** A [scripts/control_panel.html](../scripts/control_panel.html) beágyazza a [scripts/dashboard.html](../scripts/dashboard.html) oldalt. A 2026-09-18-i mérésen a weboldal elérhető volt, de a kamera, LiDAR és SLAM publikálói hiányoztak. 2026-09-19-én a C70, a `/scan` és a valódi `/map` külön Docker-konténerekből újra megjelent. Az aktuális laptopos nézet a [scripts/start-demo-view.ps1](../scripts/start-demo-view.ps1) indítóval érhető el; lásd [10-bemutato-terkep.md](10-bemutato-terkep.md).

Az önálló Xavier repóban a helyi `control_panel.html` a **bemutatóoldal**: a C70 képe és a valódi `/map` a bázisvezérlés mellett látszik. A beágyazott `dashboard.html?embed=1` csak ezt a két adatfolyamot kéri le, így a rejtett Astra- és 3D-panelek nem dolgoznak feleslegesen. A külön megnyitható `dashboard.html` a **műszaki szenzornézet**, ennek bővítése későbbi feladat. A `start-demo-view.ps1` alapból a bemutatóoldalt nyitja meg; `-DashboardOnly` kapcsolóval a műszaki szenzornézetet. A helyi HTTP-szerver a repó gyökerét szolgálja ki, ezért a dokumentációs linkek is működnek. A roboton futó 8901-es, régi weboldal ettől nem frissül automatikusan.

A repó gyökerében lévő `index.html`, `control_panel.html` és `dashboard.html` csak átirányítás: a ténylegesen szerkesztendő felületek a `scripts/` mappában vannak. A korábbi `http://127.0.0.1:8902/dashboard.html` könyvjelző is működik az új helyi szerverrel.

Ha a helyi 8080-as SSH-videóalagút megszakad, a bemutató C70-panelje kapcsolatvesztést jelez, és nyolc másodpercenként újrapróbálja az MJPEG-et. A nyers ROS-tartalék csak a külön műszaki szenzornézetben maradt: 15–31 másodperces késést okozott, és a térképet is terhelte. Az MJPEG URL 320×240 méretet kér, 55-ös JPEG-minőséggel; a robot mért képe mégis 640×480; a felhasználó 1 másodperc alatti mozgáskésést mért. A `start-demo-view.ps1` újrafuttatása a hiányzó alagutat indítja újra; ha a helyi SSH-kulcs nem olvasható, PuTTY Plinkkel kapcsolódik a dokumentált jelszó átmeneti fájljával. Részletek: [munkamenet-átadás](11-munkamenet-atadas.md).

A térképpanel **Térkép újrakezdése** gombja a helyi `:8902` szerveren keresztül csak a SLAM-konténert indítja újra; a felhasználó élőben kipróbálta. Wi-Fi átváltásnál a kamera jelenleg nem stabil; lásd a [munkamenet-átadást](11-munkamenet-atadas.md).

## Mit tud

- **Két kamera élőben**, egy oldalon:
  - **Astra RGBD** → `/camera/rgb`, `/camera/depth`, (IR csak akkor, ha az RGB ki van kapcsolva — driver-korlát, egyszerre csak az egyik megy)
  - **Wheeltec C70** (a karra szerelt USB webkamera) → `/usb_cam/image_raw`
- **Kamera mód kapcsolók** (RGB/Depth be-ki) élő `std_srvs/SetBool` hívásokkal, relaunch nélkül a lapról.
- **Depth kép saját canvas-renderelése** — a `web_video_server` nem tudja a 16UC1 nyers mélységformátumot automatikusan színes képpé konvertálni (`cv_bridge` hiba: `[16UC1] is not a color format`), ezért ezt a lap saját JavaScript-je csinálja.
- **3D point cloud + LiDAR overlay**, Three.js + OrbitControls (kattints+húzd forgatáshoz, görgő zoomhoz) — `/camera/depth/points`-ból (kék), a LiDAR `/scan` ugyanabba a 3D térbe vetítve (narancssárga).
- **Valódi 2D SLAM-térkép panel** a C70 kép mellett: `/map` (`nav_msgs/OccupancyGrid`) foglaltsági rács, frissülési állapottal. Csak akkor mutat térképet, ha ROS-oldalon tényleges `/map` üzenet érkezik; a 2026-09-19-i robotoldali publikálást és helyi megjelenést ellenőriztük.

## Korábbi kézi indítás (2026-08-25)

Az alábbi eljárás a régi, külön szenzorindítás dokumentációja. A 2026-09-18 óta dokumentált automatikus systemd-szolgáltatások mellett a `start_feeds.sh`-t ne futtasd ellenőrzés nélkül, mert folyamatokat duplázhat. Az aktuális bemutató ellenőrzési sorrendje a [10-bemutato-terkep.md](10-bemutato-terkep.md) fájlban van.

```bash
# a roboton, SSH-n át:
ssh -i ~/.ssh/pickerbot_mini wheeltec@192.168.123.50 'bash -s' < scripts/start_feeds.sh
```

Elindítja: `roscore`, Astra kamera, LiDAR, C70 usb_cam, `web_video_server`, `rosbridge_websocket`.

```bash
# helyben, a scripts/ mappában:
python -m http.server 8901
```

Majd nyisd meg: `http://127.0.0.1:8901/dashboard.html` — **fontos: ne `file://`-ként**, mert az statikus pillanatképként fut, a WebSocket-kapcsolat el sem indul.

**Mai hozzáférés:** a videókiszolgáló csak a robot `127.0.0.1:8080` címén figyel. A laptopos indító SSH-alagutat nyit, így a helyi `http://127.0.0.1:8080/` kamera-lista elérhető. A korábbi `http://192.168.123.50:8080/` cím szándékosan nem működik. A Depth 16UC1 adatát továbbra is a dashboard saját canvas-renderje kezeli.

## Technikai buktatók, amiket ez a projekt oldott meg

1. **A rosbridge Base64-ként küldi a bájttömb mezőket.** A `PointCloud2.data` és `Image.data` string, nem JSON szám-tömb. `new Uint8Array(msg.data)` csendben 0 pontot ad — `atob()`-bal kell dekódolni.
2. **A LiDAR↔kamera transzformáció be van égetve a kódba**, nem élő TF-fel megy. A `ROSLIB.TFClient` a böngészőben csak a `/tf` topicot hallgatja; a robot statikus geometriája (URDF-ből) `/tf_static`-on megy, amit a kliens sosem kap meg. Fix mechanikai szerelésnél (LiDAR és kamera egymáshoz képest nem mozdul) egyszerűbb és megbízhatóbb a mért transzformációt egyszer lekérdezni (`rosrun tf tf_echo laser camera_depth_optical_frame`) és beégetni.
3. **Az IR kapcsoló szándékosan nincs bekötve a lapon** — lásd [07-ismert-hibak.md](07-ismert-hibak.md).

## Mit nem tud (még)

- A külön megnyitott `dashboard.html` csak szenzorokat mutat. A `control_panel.html` az alvázhoz élesítés után tud `/cmd_vel` parancsot küldeni, de a webes megállítás hálózatfüggő és korábban nem állította meg időben a robotot; vészhelyzetben a fizikai leállítót kell használni. A kar és a gripper itt továbbra is csak szimuláció.
- Az Astra RGB nem akart bekapcsolni egy vizsgálat közben — ez a hiba a session lezárásakor még nyitott volt, nem lett kivizsgálva.
