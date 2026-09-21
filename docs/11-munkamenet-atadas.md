# Munkamenet-átadás — 2026-09-21

Ez a fájl a következő fejlesztőnek/agentnek adja át a **jelenlegi** állapotot. A részletes mérési előzmények a [10-bemutato-terkep.md](10-bemutato-terkep.md) fájlban, az állandó projektkontextus a repó gyökerében lévő `.ai-context.md` fájlban vannak. Jelentős feladat végén frissítsd ezt a naplót, hogy a folytatás a Git munkakönyvtárból is érthető legyen.

## A két weboldal szerepe

| Cél | Szerkesztendő fájl | Helyi URL |
| --- | --- | --- |
| Kutatók Éjszakája bemutató, most ez a fő cél | `scripts/control_panel.html` | `http://127.0.0.1:8902/scripts/control_panel.html` |
| Részletes műszaki szenzornézet, későbbi fejlesztés | `scripts/dashboard.html` | `http://127.0.0.1:8902/scripts/dashboard.html` |

A bemutatóoldal a műszaki oldal `?embed=1` módjából ágyazza be a C70 kamerát és a valódi `/map` térképet. A gyökérben lévő azonos nevű HTML-fájlok csak átirányítók. A roboton lévő `:8901` oldal korábbi telepítés, a Git-változások oda nem kerülnek fel automatikusan. A laptopos indító `scripts/start-demo-view.ps1`; a `-DashboardOnly` kapcsoló a műszaki oldalt nyitja.

## Mostani állapot és a legutóbbi újraindítás

- A felhasználó újraindította a robotot. SSH-val ellenőrizve a `pickerbot-bringup`, `pickerbot-rosbridge` és `pickerbot-webui` aktív lett; a `/map` publikálója a `slam_gmapping` volt.
- A C70 a reboot után `/dev/RgbCam -> /dev/video0` eszközként jelent meg, de a `pickerbot-c70` konténer újraindulási hibában volt, a `/usb_cam/image_raw` témának nem volt publikálója. A repó `docker/sensors/recover-c70.sh` szkriptjét a roboton futtattuk. Sikeresen visszaadott friss ROS-képkockát, 0 kilépési kóddal. A többi konténerhez és a hostszolgáltatásokhoz nem nyúltunk; mozgásparancs nem ment ki.
- A felhasználó a képet és a térképet látja. A nyers ROS-kép kezdetben 1–1,5 másodpercenként cserélődött, de a mozgás **15 másodperc késéssel** látszott. A képkocka időbélyegével a böngészőben 16,9, később 31 másodperc késést mértünk. Egy nyers rosbridge-kocka kb. 1,23 MB; a ritkítás önmagában nem oldotta meg a torlódást. A `/usb_cam/camera_info` ugyanakkor 0,2–0,4 másodperc késéssel érkezett, tehát a kameraforrás friss volt.
- A helyi SSH-kulcsot ez az agent-fiók `Permission denied` miatt nem olvassa, bár a fájl létezik. A dokumentált jelszóval a már telepített PuTTY `plink.exe` sikeresen kapcsolódott; a robot hostkulcsának ujjlenyomatát a helyi `known_hosts` alapján rögzítettük. A jelszó csak átmeneti helyi fájlba került, amelyet a kapcsolat létrejötte után töröltünk. Az indító most ugyanezt a Plink-utat használja tartalékként, ha a privát kulcs nem olvasható. A jelenlegi `:8080` alagút Plinkkel fut; a helyi `:8902` szerver továbbra is a repó aktuális oldalát szolgálja ki.
- A korábbi teljes méretű MJPEG-folyam régi kockákat halmozott: 12 másodperc alatt csak 3 kocka érkezett, a harmadik már 6,8 másodperces volt. A `scripts/dashboard.html` C70 URL-je **320×240 méretet kér, JPEG-minőség 55-tel**, de a robot jelenlegi web_video_server változata a méretkérést figyelmen kívül hagyja: a mért kép valójában **640×480**. Kábelen ezzel 5 másodperc alatt 148 kocka érkezett, a továbbítási késés legfeljebb kb. 0,1 másodperc volt. A felhasználó külön, kézmozdulattal **1 másodperc alatti** látható késést igazolt. Az oldal `Kamera: élő MJPEG` állapotot és friss 384×384-es `/map` térképet mutatott.
- A bemutató beágyazott nézete MJPEG-kieséskor nem iratkozik fel a torlódó nyers ROS-képre. Kapcsolathibát jelez, 8 másodpercenként valódi JPEG-pillanatképpel (15 másodperces határidővel) vizsgálja a kamera és az alagút elérhetőségét, majd siker esetén csak a beágyazott szenzornézetet tölti újra. A külön műszaki szenzornézetben a nyers ROS-tartalék és a kocka mért késése megmaradt. Ez a változás a térkép és az alvázvezérlés rosbridge-kapcsolatát védi.
- Kontrollált helyi kiesési próba: a Plink-alagutat leállítottuk; a bemutatóoldal kapcsolathibát jelzett, a `/map` közben tovább frissült. Az indító `-NoBrowser` újrafuttatása új Plink-alagutat nyitott. Az első változatnál kézi oldalfrissítés kellett a képhez; a pillanatképes visszatérés után ugyanebben a próbában **kézi frissítés nélkül** újra `Kamera: élő MJPEG` és friss 384×384-es térkép jelent meg. Az indító meglévő Plink-folyamattal végzett ismételt futtatása és a teljes Plink-újraindítás is sikerült. A jelszót tartalmazó átmeneti fájl nem maradt meg.

## Gemini változásainak ellenőrzése

A helyi `main` közelmúltbeli commitjai: `392e363` (korábbi funkciók átvitele) és `a9f3197` (indító újraindítása). A Gemini után ellenőrzött változás az `a9f3197`; a `main` jelenleg egy committal az `origin/main` előtt van. A felhasználó kezeli a commitot és a push-t. Az `a9f3197` javítása újrafuttatáskor helyreállítást célzott, de részleges kieséskor a működő helyi szervert is `Stop-Process -Force` hívással leállította. Ezt módosítottuk: a futó oldal megmarad, csak a hiányzó folyamat indul újra, és sikertelen új folyamat esetén csak azt állítjuk le. Az indító **újrafuttatásra javít**, nem önálló háttérfelügyelet; automatikus SSH-újracsatlakozás nincs igazolva.

## Biztonság és következő munka

- A kar fel-le ízülete a felhasználó szerint darál és sípol. A webes karpanel továbbra is kizárólag szimuláció. Élő karpróba csak áramtalanított fizikai ellenőrzés után.
- Az alváz webes vezérlése élesítés után valódi `/cmd_vel` parancsot küld. A webes megállítás hálózatfüggő; mozgáspróbához fizikai leállító kell. Ebben a munkamenetben nem élesítettük és nem mozgattuk a robotot.
- A bemutatóoldal finomítása az elsődleges feladat. A teljes műszaki szenzornézet bővítése későbbi szakasz.
- Következő mérés: az alagút hosszabb idejű tartóssága; a térkép frissessége mozgás alatt csak felügyelt, fizikai leállítóval végzett próba során. A C70 USB-leválás okát (kábel/hub/táp) külön vizsgáld. Az indító újrafuttatásra javít, háttérben automatikus SSH-újracsatlakozás még nincs. A jelenlegi oldalt egyelőre a laptop `:8902` portján nyisd; a robot `:8901` oldalát nem frissítettük.

## Helyi változások és ellenőrzés

A mostani, felhasználó által még commitolandó változások: `scripts/start-demo-view.ps1`, `scripts/stop-demo-view.ps1`, a két `scripts/*.html` oldal, ez az átadási napló és kapcsolódó dokumentáció. Ellenőrizve: PowerShell parser hibamentes; a két HTML inline JavaScriptje `node --check` alatt hibamentes; `git diff --check` hibamentes (csak Git sorvégjel-figyelmeztetés); a 25 meglévő Python-teszt átment közvetlen függvényhívással, mert ebben a helyi Pythonban nincs telepített `pytest`. A Plink-alagút és az élő MJPEG-folyam kábelen mérve működött. Az indító meglévő Plink-folyamatot felismerő újrafuttatása, a jelszavas teljes Plink-újraindítás és a böngésző automatikus kamera-visszatérése átment. Ne commitolj vagy pusholj a felhasználó helyett.

## 2026-09-21: térkép törlése és USB Wi-Fi

- A bemutató és a műszaki oldal térképpaneljén van **Térkép újrakezdése** gomb. A `scripts/demo_server.py` csak a laptop `127.0.0.1:8902` címén fogadja a helyi POST-kérést, ellenőrzi az Origin/Host/action mezőket, és csak a `pickerbot-slam` konténert indítja újra. Az addigi térképkép eltűnik, az új `/map` adatból rajzolódik újra. A felhasználó a gomb működését élőben megerősítette. A szerver a jelszót a meglévő README-ből olvassa, átmeneti helyi fájlt használ a Plinkhez, majd törli. Ne add ki a helyi szervert a hálózatra. A robot régi `:8901` oldalán a gomb nincs telepítve.
- A TP-Link TL-WN823N / RTL8192EU stick `wlan1` eszközként működik. A roboton a `pickerbot-robot-wifi` NetworkManager-profil automatikusan kapcsolódik a `TP-Link_A426` SSID-hez, címe `192.168.123.51/24`; a Wi-Fi jelszó csak a robot root-jogú, `0600` módú profiljában van. A `scripts/robot-wifi-failover.sh` telepített példánya `/etc/NetworkManager/dispatcher.d/90-pickerbot-wifi-failover`; Ethernet kiesésekor a ROS által használt `.50/32` címet a Wi-Fi-re teszi, visszatéréskor leveszi. A robot saját `wlan0` hotspotját nem módosítottuk.
- **Kontrollált próba, fizikailag bent hagyott kábellel:** az `eth0` kapcsolatot logikailag lekapcsoltuk, és 180 másodperces automatikus visszakapcsolást állítottunk be. A `.50` Wi-Fi aliasról SSH, a 9090-es rosbridge és a 8901-es webport elérhető volt, az útvonal `wlan1`-et mutatott. A roboton a `/map` és C70 publikálók futottak. A böngészőben a térkép az újrakapcsolás után ismét megjelent, de az MJPEG-kamera Wi-Fi-n ismételten megszakadt, és a pillanatkép-kérés több másodpercig tarthatott. A rosbridge szolgáltatást és a web-video konténert egyszer újraindítottuk; a SLAM-et, C70-et, LiDAR-t, bringupot és a kart nem indítottuk újra. A próba után az Ethernet automatikusan visszaállt, a bemutatóoldal ismét `Kamera: élő MJPEG` állapotot és friss, 384×384-es térképet mutatott. A Wi-Fi átállás így még **nem kész bemutatóüzemre**; valódi kábelkihúzást és újraindítást kábel nélkül nem igazoltunk.
- A kezdeti Wi-Fi jel körülbelül −78 dBm, a feltöltési link 6,5 Mbit/s volt. A felhasználó kb. 50 cm-rel közelebb vitte az eszközöket; ekkor −36 dBm és 39 Mbit/s volt mérhető, de a böngészős stream így sem bizonyult stabilnak az átváltás során. A bemutató helyén, végleges távolságon új mérés kell. A robot web_video_serverének 640×480-as tényleges képe a szűk Wi-Fi linken torlódhat; a méretcsökkentéshez szerveroldali megoldás kell, az URL-paraméter önmagában nem elég.

**Folytatás:** mérd a kamera HTTP MJPEG-folyamának képkockaidejét és méretét Wi-Fi-n; ellenőrizd, hogy az SSH-alagút hálózatváltás után új kapcsolatot nyit-e. Ha szükséges, készíts a roboton külön, kisebb felbontású/képkockasebességű bemutatófolyamot, a meglévő ROS-témát érintetlenül hagyva. Próbáld ki a tényleges kábel nélküli indítást csak visszaállítási tervvel és a bemutatóhelyen. A karral továbbra se végezz mozgáspróbát a fizikai hiba felderítéséig.
### Második Wi-Fi próba és helyreállítás, 2026-09-21 12:00

A második, 180 másodperces Ethernet-visszakapcsolással védett próbában a Wi-Fi-re új SSH-videóalagutat akartunk nyitni. Ez nem indult el. Utólag a NetworkManager naplója megmutatta, hogy a `wlan1` **már 11:49:34-kor**, a próba előtt elvesztette az AP-kapcsolatot; 11:49:50-kor `ssid-not-found` hibára váltott. Emiatt az Ethernet logikai lekapcsolása után sem a `.50`, sem a `.51` cím 22/9090 portja nem volt elérhető. Az időzített `nmcli device connect eth0` 11:56-kor visszaállította az Ethernetet. A `wlan1` azóta `disconnected` állapotú; a Wi-Fi-keresés üres listát adott, a célzott `nmcli connection up pickerbot-robot-wifi ifname wlan1` szintén „The Wi-Fi network could not be found” hibával zárult. Az USB-s eszköz (`2357:0109`) jelen van, a rádió nincs blokkolva. A kernelnaplóban 11:49-kor AP-hitelesítési időtúllépés és `Unhandled C2H event` üzenetek vannak. Az ok (jel/AP, stick, USB-ellátás vagy `rtl8xxxu` driver) nincs bizonyítva; jelenleg a robot **nem használható kábel nélkül**. További Ethernet-lekapcsolást csak akkor végezz, ha a `wlan1` előbb újra csatlakozott és a `.51` SSH-portja elérhető. Szükség esetén fizikailag ellenőrizd/dugd újra a sticket, majd nézd meg az AP láthatóságát és a router naplóját.

A hálózatváltás után a vezetékes böngészőoldal képe és térképe átmenetileg nem tért vissza. A `pickerbot-rosbridge` szolgáltatás és a `pickerbot-web-video` konténer újraindítása, majd az oldal frissítése visszaadta az élő MJPEG képet. A LiDAR `/scan` kb. 12 Hz-cel futott, de a SLAM `/map` nem adott új üzenetet; ezért a `pickerbot-slam` konténert újraindítottuk. Ez törölte az addig épített belső térképet, az új térkép viszont megjelent és ismét üzeneteket küldött. A végső böngészőállapot: `Kamera: élő MJPEG`, `Térkép: üzenetek érkeznek`, 384×384. Mozgásparancsot nem adtunk. A helyi indító fut, az aktuális bemutatóoldal `http://127.0.0.1:8902/scripts/control_panel.html`.

## 2026-09-21: a beépített Wi-Fi lett az elsődleges vezeték nélküli út

- A felhasználó kihúzta és visszadugta az USB Wi-Fi sticket. Ezután a `wlan1` ismét kapcsolódott, de a mért jel −82 dBm volt. A robot saját rádiója a beépített Intel 8265 (`wlan0`); korábban a `WHEELTEC_OrinSuper_Noetic_JP515` hotspotot sugározta.
- Az Ethernet megtartása mellett a robot védett USB Wi-Fi profiljából átvett jelszóval létrehoztuk a `pickerbot-onboard-wifi` kliensprofilt a `TP-Link_A426` hálózathoz. A beépített Wi-Fi címe `192.168.123.52/24`, útvonal-metrikája 150; az USB profil `.51/24` címe és 200-as metrikája tartalékként megmaradt. A jelszót nem írtuk a repóba. A beépített kapcsolat első jele −21 dBm volt az akkori közeli elhelyezésben; ez nem a bemutatóhelyen mért adat.
- A `scripts/robot-wifi-failover.sh` most Ethernet kiesésekor először a beépített `wlan0`-ra, ennek hiányában a `wlan1`-re helyezi a ROS `192.168.123.50/32` alias címét. A szkriptet a robot `/etc/NetworkManager/dispatcher.d/90-pickerbot-wifi-failover` helyére telepítettük, szintaxisát és vezetékes ágát ellenőriztük.
- **Kontrollált próba:** 120 másodperces automatikus Ethernet-visszakapcsolást állítottunk be, majd logikailag lekapcsoltuk az `eth0`-t. Az USB Wi-Fi ekkor `DOWN` volt. A `.50` alias a `wlan0`-n jelent meg, az SSH a robot megszokott `.50` címén működött, a laptop felé az útvonal `dev wlan0` volt. A laptopos bemutatóoldal ekkor `Kamera: élő MJPEG` és változó 384×384-es térkép állapotot mutatott. Mozgásparancs nem ment ki. Az időzített Ethernet-visszakapcsolás után a `.50` visszakerült kizárólag az `eth0`-ra, a `wlan0` `.52` címmel csatlakozva maradt. A régi hotspot-visszaállító időzítőt a sikeres próba után leállítottuk.
- A `pickerbot-onboard-wifi` automatikus kapcsolódása be van kapcsolva; a régi hotspot profilját megőriztük, de az automatikus indulását kikapcsoltuk. A két mód ugyanazt a rádiót használja, így most a robot saját hotspotja nem sugároz. Helyben `sudo nmcli connection up WHEELTEC_OrinSuper_Noetic_JP515 ifname wlan0` paranccsal visszaállítható, de ez megszünteti a TP-Link klienskapcsolatot. A dokumentált hozzáférés és ellenőrzés a [hálózati leírásban](09-robot-halozat.md) van.

**Még ellenőrizendő:** tényleges fizikai kábelkihúzás, indítás kábel nélkül, tartósság és kamerakésés a bemutató tervezett távolságán. A kontrollált próba a hálózati útvonalat és a két élő szenzornézetet igazolta; a bemutatóhelyen szükség lehet további jel- vagy videófolyam-optimalizálásra. A robotkarral továbbra se végezz élő mozgáspróbát a fizikai hiba kivizsgálásáig.

**Hosszabb utóellenőrzés:** az Ethernet visszatérése után a kamera élő maradt, de a `/map` nem adott új üzenetet egy 8 másodperces közvetlen ROS-mérésben, és a bemutatóoldal 15 másodperces frissességi figyelmeztetést mutatott. A `pickerbot-slam` újraindítása után is megismétlődött ez az állapot. Ez külön **SLAM/TF vagy álló robot melletti publikálási kérdés**, nem bizonyított Wi-Fi-hiba; a pillanatnyi kép látható, de az új térképüzenetek tartóssága nem igazolt. Következő lépésként felügyelt, fizikai leállítóval végzett mozgás közben hasonlítsd össze a `/scan`, `/tf`, `/map` időbélyegeit és a gmapping naplóját. A kart ne mozgasd. A beépített Wi-Fi a későbbi ellenőrzéskor is csatlakozott a TP-Linkhez, `wlan0` jelerőssége −27 dBm és adási linkje 300 Mbit/s volt; az Etherneten a `.50`, a beépített Wi-Fi-n a `.52` cím maradt.

### Fizikailag kihúzott USB-stick próbája

A felhasználó kihúzta a TP-Link USB Wi-Fi sticket. A roboton a `wlan1` eltűnt az eszközlistából; a beépített `wlan0` továbbra is a `TP-Link_A426` hálózaton maradt, a méréskor −33 dBm jellel és 300 Mbit/s adási linkkel. Az Ethernetet újabb 120 másodperces automatikus visszakapcsolással védett próbában logikailag lekapcsoltuk. A megszokott `.50` alias a `wlan0`-n jelent meg, az SSH és a bringup/rosbridge aktív volt, a laptop felé az útvonal `dev wlan0` lett. A videóalagút indítójának újrafuttatása után a C70 pillanatkép HTTP 200 választ adott **0,64 másodperc** alatt (20 439 bájt), és a bemutatóoldal élő MJPEG-képet, valamint változó tartalmú 384×384-es térképet jelzett. Az automatikus Ethernet-visszakapcsolás ezután lefutott: a `.50` cím kizárólag az `eth0`-n volt, a `wlan0` `.52` címen kapcsolódva maradt, az oldalon a kamera és a változó térkép továbbra is látszott. A mérés az adott helyen, rövid ideig tartott; a hosszú távú kamera- és térképfrissülést külön kell ellenőrizni. Valódi fizikai Ethernet-kábel kihúzása továbbra sem történt meg.

## 2026-09-21 (délután): kábel nélküli próba a felhasználó megfigyelése alapján

**Mit igazoltunk (a felhasználó szerint, számszerű mérés nélkül):** a felhasználó kihúzta az Ethernet-kábelt, és a robotot a beépített Wi-Fin (`wlan0`, TP-Link_A426) használva körbevitte a szobában. A bemutatóoldal működött, a rosbridge kapcsolat, a kamera és a térkép megjelent. Ez az első fizikai kábelkihúzásos próba. Kábel nélküli **újraindítást** nem próbáltunk.

**Problémák:**
- A kamerakép 1–2 percenként megszakadt. Az alagút (`start-demo-view.ps1`) újrafuttatása után egy ideig ismét működött. Egy alkalommal a felhasználó szerint a kép kb. 3 perc után magától tért vissza. Ez inkább a Wi-Fi-kapcsolat megakadására utal, mint az SSH-folyamat megszűnésére (az `ssh` 30 másodperc után feladja), de az ok **nincs bizonyítva**.
- A kamera késése kábel nélkül a felhasználó szerint túl nagy egy izgalmas bemutatóhoz. Nincs számszerű mérés; a korábbi ismert ok, hogy a robot `web_video_server` a 320×240 URL-kérés ellenére 640×480 képet küld.

**Mit változtattunk (a laptopon, a roboton semmit):**
- `scripts/start-demo-view.ps1` és `scripts/stop-demo-view.ps1`: UTF-8 BOM. Nélküle a Windows PowerShell 5.1 az ékezetes szöveget ANSI-ként olvasta, és szintaxishibával leállt.
- Új `scripts/watch-demo-view.ps1`: 10 másodpercenként egy JPEG-pillanatképet kér az alagúton át, két sikertelen kör után lefuttatja a `start-demo-view.ps1 -NoBrowser` parancsot. Naplót ír a `%TEMP%\pickerbot-demo-watch.csv` fájlba (idő, siker, válaszidő másodpercben, méret bájtban, újraindítás). **Szintaxisát és működését még nem futtattuk le**, itt nincs PowerShell.

**Következő lépések:** futtasd a `watch-demo-view.ps1`-et kábel nélkül, és a napló megmutatja a kiesések gyakoriságát és a válaszidőt. Olvasó mérések a roboton (`iw dev wlan0 link`, `iw dev wlan0 get power_save`) és laptopról `ping -n 60 192.168.123.50`. Ezek után dönthető el, hogy a kamera forrását kisebb felbontásra/kevesebb képkockára kell-e állítani (`pickerbot-c70` konténer újra létrehozása, robotoldali változtatás, külön jóváhagyással).

### Alagút-őrző mérése kábel nélkül, 2026-09-21 13:43–13:48

**Mérve** (`scripts/watch-demo-view.ps1`, 10 másodperces JPEG-pillanatkép az alagúton át, kb. 5 perc): 30 kérésből 30 sikerült, automatikus újraindítás nem történt. A válaszidő mediánja 0,17 s, két kiugró érték 3,62 s és 2,88 s volt (13:44:38 és 13:44:51), a többi 0,07–0,69 s. A kép mérete 12–23 kB. A felhasználó szerint a kamera ezúttal gyors volt, és nem szakadt meg. A pillanatkép egyetlen kép lekérése, ezért **nem** a folyamatos MJPEG-videó késését méri.

**Bizonytalan:** az előző kör 1–2 percenkénti megszakadásai ebben a mérésben nem ismétlődtek meg; az okuk (helyváltoztatás, Wi-Fi-jel, roaming, az akkori terhelés) nincs kiderítve. A két kb. 3 másodperces megakadás a Wi-Fi rövid kiesésére utalhat, ez sincs bizonyítva. A mérés egy szobában, egyetlen 5 perces futásból származik.

**Térkép:** az 5 perces körözés alatt a `/map` egy idő után szétcsúszott (egymásra fordult, elcsúszott falak). A körülmények, főleg hogy a robotot kézzel vitték-e (ilyenkor a kerékodometria nem mozdul), vagy hajtották, nincsenek rögzítve. Ez a korábbi, nyitott SLAM/TF-kérdés része; a szétcsúszás oka nem bizonyított.

### Térkép-elcsúszás vizsgálata és robotoldali mérés, 2026-09-21 14:10–14:20

A felhasználó joystickkel vitte a robotot (a joystick közvetlenül az alsó vezérlőhöz kapcsolódik, a webes sebességplafon nem érvényes rá), és gyors fordulások közben a `/map` szétcsúszott (egymásra fordult, elcsúszott falak). A `scripts/robot-slam-diag.ps1` csak olvasó módon mért a roboton, álló helyzetben.

**Mért:**
- `/scan` 12,0 Hz (szórás 0,0002 s), `/odom` 20,0 Hz, `/imu` 20,0 Hz, `/tf` kb. 100 Hz. A gmapping bemenetei nem estek ki.
- `/map` 10 másodperces mérésben 0,44–1,6 Hz, legfeljebb 3,1 másodperces szünetekkel. A `temporalUpdate` értéke 1 s, így álló robotnál ez várható; a mérés idején mozgás nem volt.
- `wlan0`: −28 dBm, 270–300 Mbit/s, **Power save be van kapcsolva**. A hatása nincs mérve, a beállítást nem módosítottuk.
- SLAM-napló (utolsó ~150 sor, álló robotnál): az átlagos illesztési pontszám kb. 1430–1460, `neff` 6,5 körül (8 részecskéből), a pozíció gyakorlatilag nem mozdul (`ad` ~1e-9). Az álló állapot tehát stabil. A CPU-terhelés (`docker stats`) sora nem került elő.

**Nem mért / bizonytalan:** a szétcsúszás mozgás közben történt, de mozgás közbeni SLAM-napló és CPU-terhelés nincs. Nem tudjuk, hogy a gmapping fordulás közben lemarad-e (8 részecske, 12 Hz-es scanek), vagy a kerékodometria csúszása okozza-e (mecanum). A `docker/slam/gmapping-tuned.launch` (20 részecske, nagyobb forgási zaj, minimumScore 50) egy **kipróbálatlan** ötlet, még nincs telepítve; a robot konténere a régi `gmapping.launch`-ot használja.

**Következő lépés:** mozgás közbeni mérés. Új térképpel indítva (a `pickerbot-slam` újraindítása törli a térképet), felügyelt, lassú, majd gyorsabb joystickos fordulás közben és közvetlenül utána: `sudo docker stats --no-stream pickerbot-slam` és a naplóban a „Dropped”/„Failed” sorok, valamint az `Average Scan Matching Score` legalacsonyabb értékei. Utána döntsük el, kell-e a tuned fájl.

### SLAM mozgás közben, 2026-09-21 14:27

Az újraindított `pickerbot-slam` (új, üres térkép) után a felhasználó joystickkel vezette a robotot, gyors fordulásokkal; a térkép enyhén szétcsúszott. A `robot-slam-diag.ps1` a mozgás után futott.

**Mérve (SLAM-napló és `docker stats`):**
- A konténer CPU-terhelése 6,5%, memóriája 43,6 MiB. A gmapping **nem processzorkorlátos**, és a naplóban a mozgás közben minden feldolgozott scan után volt frissítés (nincs kihagyott „update frame” sorozat a mozgás alatt).
- A gyors forduláskor az odometria egy lépésben (`ad`) 0,47–0,87, majd 2,13 és 1,22 rad elfordulást jelentett két egymás utáni scan között (kb. 83 ms). Ekkor az illesztési pontszám 1490-ről 1110, 864 és 919 értékre esett, a hasznos részecskék száma (`neff`) 1-re, és többszöri újramintavételezés történt („RESAMPLE”). Utána `neff` 7-re állt vissza, a térkép azonban már a hibás pozícióval épült tovább.
- A `/scan` 12,0 Hz, `/odom` 20,0 Hz, `/imu` 20,0 Hz (az IMU időzítése ekkor szabálytalan volt: 0,025–0,075 s között ingadozott, a korábbi mérésnél egyenletes volt), `/tf` kb. 100 Hz.
- Wi-Fi: −28 dBm, 243–300 Mbit/s, **Power save be**, csatorna 2452 MHz (2,4 GHz, 40 MHz széles). A `TX` bájtszámláló a 14:14 és 14:27 közötti kb. 13 percben 1,47 GB-tal nőtt, ez kb. 15 Mbit/s tartós feltöltés a robot felől (a 14:10-es és 14:14-es érték között a számláló valószínűleg 32 bites túlcsordulással nullázódott; ezt nem ellenőriztük).

**Következtetés (nem bizonyított, de a mérésekkel egyezik):** a szétcsúszást nem a CPU, nem a scan/odom kiesése és nem a Wi-Fi okozta, hanem a gyors fordulás: néhány scan alatt több radiánnyi odometria-ugrás, és a scan is torzul, mert a LiDAR 83 ms alatt körbeér, miközben a robot közben elfordul. A részecskék összeomlanak (`neff` 1), a 8 részecske és a `gmapping-tuned.launch` (20 részecske) ezt valószínűleg **nem** oldja meg; a fordulási sebesség korlátozása többet segít. A robot valós maximális szögsebessége és a joystick sebességfokozata nincs feltárva.

**Kamerakésés:** a felhasználó szerint a kép a mérés idején késni kezdett. A késés nincs számszerűen mérve. A ~15 Mbit/s tartós feltöltés a 640×480-as MJPEG-folyamból adódhat; a kisebb felbontású/kevesebb képkockás forrás a forgalmat csökkentené, de ezt még nem próbáltuk ki.

**Következő lépések:** (1) a joystick/távirányító sebességfokozatának vagy szögsebesség-korlátjának felkutatása, és térképezéskor lassú fordulás (kb. 0,1 rad/scan alatt, azaz 1 rad/s alatt); (2) az IMU szabálytalan időzítésének vizsgálata; (3) kamera: kisebb felbontás/képkockaszám a forrásnál (robotoldali változtatás, külön jóváhagyással).

### 2026-09-21: forgási sebesség csúszka a bemutatóoldalon

- `scripts/control_panel.html`: a bázispanelen új **forgási sebesség** csúszka (0,10–1,00 rad/s, alapérték és újratöltés utáni érték 0,30 rad/s, tehát a korábbi plafon változatlan). Piros vonal jelöli a 0,60 rad/s határt; fölötte figyelmeztetés jelenik meg és a naplóba is bekerül. Csökkentéskor a már kiküldött forgás azonnal az új határra vágódik.
- **Csak a webes forgatógombokra vonatkozik**, a fizikai távirányítót nem korlátozza (az az alsó vezérlőhöz kapcsolódik). A lineáris plafon (0,15 m/s) és a `base_drive.py` értékei nem változtak.
- A 0,60 rad/s határ **becslés, nem mért érték** (12 Hz-es LiDAR mellett kb. 0,05 rad/szkennelés). A mért összeomlás sokkal magasabb sebességnél történt (kb. 0,5 rad/szkennelés).
- Ellenőrzés: az inline JavaScript `node --check` alatt hibamentes; headless böngészőben (ROS-tár nélkül, csonkolt `ROSLIB`-bal) a csúszka, a figyelmeztetés és a kiírt plafon a várt módon változott, JS-hiba nélkül. Valódi robottal, élesítéssel **nem** próbáltuk ki.
- Új `.gitignore`: `slam-diagnosztika.txt` (a diagnosztikai szkript kimenete), Python-gyorsítótárak.
