# Saját projekt #3 — kézi vezérlés (bázis + kar)

**Friss állapot 2026-09-18, két rebootpróba után:** a duplán indult bringup, a hibás `senior_mec_bs` mód és a rosbridge/master indulási versenye rendezve. Egy `mini_mec_moveit_four` bringup fut; a `/wheeltec_robot` válaszol, `/odom`, `/imu` és `/PowerVoltage` friss. A feszültség 23,33 V körüli volt. A lentebb olvasható sikeres `/cmd_vel` és `/arm_cmd` mozgáspróbák **korábbi állapotra** vonatkoznak; a mostani helyreállítás során nem küldtünk mozgásparancsot. A régi `start_feeds.sh` szkriptet ne indítsd a systemd-szolgáltatások mellé. Részletek: [10-bemutato-terkep.md](10-bemutato-terkep.md).

**Építve: 2026-09-18, robot offline (SSH nem elérhető) — semmi ebből nem lett élő roboton tesztelve.** Célja: a meglévő, csak-megfigyelő [05-sajat-projekt-iranyitopult.md](05-sajat-projekt-iranyitopult.md) irányítópult kiegészítése tényleges bázis- és kar-vezérléssel, ugyanazzal a biztonsági doktrínával, mint amit a testvér-repóban ([NERO_GO2](../) fő projekt, Go2 négylábú) a `docker/web_dashboard/joint_safety.py` + `lowcmd_sender.py` mock/real-split párra építettünk.

**FONTOS:** ez a robot **nem** a Go2 négylábú. Mecanum-alváz + 4 DOF kar, ROS1 Noetic (nem DDS/LowCmd). A Go2 ízület-számokat, sebesség-plafonokat sehol nem vettük át — minden itt szereplő szám ezen a roboton, ehhez a hajtáshoz lett (óvatosan) kitalálva, vagy explicit PLACEHOLDER-ként jelölve.

## Mi épült

| Komponens | Fájl | Állapot |
|---|---|---|
| Bázis (mecanum) Twist-építő + rate-limiter | [scripts/xavier_control/base_drive.py](../scripts/xavier_control/base_drive.py) | **valós-képes** — de csak ha valaki ténylegesen bekötné egy publish hívásba; a modul maga csak dict-eket épít |
| Kar/gripper mock sender | [scripts/xavier_control/arm_control.py](../scripts/xavier_control/arm_control.py) | **MOCK-ONLY** — szándékosan nem tud valós ROS API-t hívni |
| Webes vezérlőpult | [scripts/control_panel.html](../scripts/control_panel.html) | bázis: valós `/cmd_vel`; kar/gripper: valós `/arm_cmd`; mindkettő külön élesítés mögött, alapból KI |
| Unit tesztek | `scripts/xavier_control/tests/test_base_drive.py`, `test_arm_control.py` | 25/25 zöld (`python -m pytest tests/` a `xavier_control/` mappában) |

## Valós-képes vs. mock-only — és miért ez a különbség

**Bázis-vezérlés (`/cmd_vel`, `geometry_msgs/Twist`) valós-képesnek számít**, mert:
- Ez a Wheeltec `turn_on_wheeltec_robot` alap-driver saját, jól dokumentált konvenciója, amit a gyári `wheeltec_joy_control` package is használ.
- Egy Twist (linear.x/y, angular.z) formátumhoz nem kell ízület-szintű geometriai adat, ami hiányzik — csak sebesség-parancs.

**A kar webes küldése 2026-09-23 óta élőre beköthető.** A felhasználó kérésére a kezelő felügyeli a mozgást. A `/arm_cmd` topic és a gripper konvenciója ismert, de az alsó vezérlő nem küld vissza mért karpozíciót. Minden parancs négy értéket tartalmaz, ezért egy grippermódosítás is újraküldi mindhárom kartengely célját.
- A gripper gyári tartománya `0..100`: `0 = nyitva`, `100 = zárva`, a gyári kézi vezérlő lépése `5`.
- A biztonságos karfelület nem abszolút csúszkákat használ, hanem a gyári kódhoz illeszkedő kis lépéses gombokat: talp ±0,02 rad; karvég X/Y ±0,01 m; gripper ±5.
- A gombos modell a gyári ízületi és munkatérkorlátokat ellenőrzi. A weboldal külön `KAR ÉLESÍTÉS` után publikál; a Python `arm_control.py` modul továbbra is mock-only.
- Oldalbetöltés, ROS-újracsatlakozás, bázisélesítés és a parancsmodell alaphelyzetbe állítása nem küld `/arm_cmd` üzenetet.

## A biztonsági plafonok pontos értékei és miért ilyenek

`scripts/xavier_control/base_drive.py`:

| Paraméter | Érték | Eredet |
|---|---|---|
| `MAX_LINEAR_MPS` | 0.15 m/s | **Óvatos alapérték, NEM mért hardver-plafon.** Nincs adatlap, nincs mért csúcssebesség ezen a példányon. |
| `MAX_ANGULAR_RADPS` | 0.3 rad/s | Ugyanaz — óvatos becslés, nem mérés. |
| `MAX_LINEAR_ACCEL_MPS_PER_TICK` / `MAX_ANGULAR_ACCEL_RADPS_PER_TICK` | 0.03 / 0.06 (tick ≈ 1/20 s referenciánál) | Cél: ~0.5s alatt érje el a max sebességet egy tartott gombnál, ne egy UI-kattintásra ugorjon oda azonnal. |

Ha az első élő teszten a robot gyorsabban mozog a vártnál ezekkel az értékekkel, **csökkentsd tovább** ezeket a számokat — ne emeld feljebb egy sikeres teszt után anélkül, hogy tudnád, mi a valós fizikai plafon.

**Fontos, 2026-09-23-i frissítés — a fenti táblázat SZÁNDÉKOSAN elavult marad, ne igazítsd hozzá a webes felületet:** a `base_drive.py` modul (ld. fent a "Mi épült" táblázatot) jelenleg **nincs bekötve** semmilyen valós `/cmd_vel`-publisherbe — csak dict-eket épít, a saját unit tesztjein kívül semmi nem hívja élesben. A fenti `MAX_LINEAR_MPS`/`MAX_ANGULAR_RADPS` értékek tehát ma **nem korlátozzák a robot tényleges mozgását**.

Ezzel szemben `scripts/control_panel.html` a fizikai kontrollerrel 2026-09-23-án, a meglévő telemetria-panellel felügyelten mért valós csúcsértékekre lett kalibrálva: a webes csúszkák felső határa forgásra 0,98 rad/s, oldalazásra 0,57 m/s, előre-hátrára 0,55 m/s — ez ma a ténylegesen élő, kemény korlát a webes vezérlésre (a felhasználó megerősítése szerint a csúszka jobb szélén sem lehet a fizikai kontrollernél gyorsabb parancsot kiküldeni). A csúszkák induló (alapértelmezett) értéke a felhasználó kérésére mindhárom tengelyen 0,5 (0,5 m/s / 0,5 m/s / 0,5 rad/s). Részletek: [11-munkamenet-atadas.md](11-munkamenet-atadas.md).

Ha valaha a `base_drive.py` modult tényleges publisherbe kötik, akkor ott is a fent mért értékekre (vagy azoknál óvatosabbra) kell állítani a konstansokat, és ezt a táblázatot frissíteni kell — addig a két fájl közti eltérés szándékos, nem hiba.

`scripts/xavier_control/arm_control.py` `JOINT_LIMITS_RAD` értékei a betöltött URDF óvatos ±0,785 rad határai. A roboton talált gyári `stepper_arm/src/stepper_motor_arm.cpp` ettől eltérő mechanikai modellt használ: j1 `[-1,9; 1,9]`, j2 `[-0,17; 1,5708]`, j3 `[0,3918; 2,2981]` rad, továbbá `j2+j3 >= π/2` és öt munkatérív is korlátozza a karvéget. A webes szimuláció ezeket a gyári, összetett korlátokat használja; a Python modul megmarad a szűkebb, mock-only tartományban.

## 2026-09-23: a kar- és grippervezérlés lezárt műszaki állapota

Olvasó jellegű robotvizsgálattal, mozgásparancs nélkül ellenőrizve:

- `/arm_cmd` típusa `std_msgs/Float32MultiArray`, sorrendje `[j1_rad, j2_rad, j3_rad, gripper]`.
- A gripper skálája biztosan `0..100`; a gyári automata pick kód `100` értékkel zár és `0` értékkel nyit.
- A vezérlő soros visszajelző csomagja csak alvázsebességet, IMU-adatot és akkufeszültséget tartalmaz. Valódi ízületi pozíció vagy szervóhiba nem érkezik vissza.
- A ROS `/joint_states` karértékei nullák és modelladatok, nem szenzormérések.
- Emiatt az abszolút csúszkás vezérlés elvetve. A webes panel kis lépéses, gyári kinematikát követő gombokat használ, és külön kar-élesítés után publikál `/arm_cmd` üzenetet.

**Élő használat:** a karpanel `KAR ÉLESÍTÉS` gombja független a bázis élesítésétől. Egy rövid kattintás vagy billentyűlenyomás egy finom parancslépést küld; nyomva tartáskor ugyanez a lépés 100 ms-onként ismétlődik. Magyar QWERTZ billentyűk: `C/V` talp balra/jobbra; `R/F` karvég előre/hátra; `T/G` fel/le; `H/J` gripper nyit/zár. A folyamatos ismétlés elengedéskor, elveszett billentyű-heartbeatnél (850 ms), fókuszvesztéskor, háttérbe kerüléskor, ROS-kapcsolatvesztéskor, munkatér- vagy gripperhatárnál, illetve legfeljebb 15 másodperc után leáll. A parancsmodell alaphelyzete `[0, 1.570796, 0.391797, 0]`; az első élő lépés ebből indul.

## Első élő teszt — lépésről lépésre (amikor a robot legközelebb elérhető)

Ne kezdd el ezt a listát, amíg nincs valaki a robot közelében, aki fizikailag el tudja kapcsolni az áramot (tápkapcsoló/battery), és amíg nincs meg a `rostopic`-os megerősítés.

1. **SSH-kapcsolat + ROS master él.** `ssh -i ~/.ssh/pickerbot_mini wheeltec@192.168.123.50`, majd `rosparam get /run_id` paranccsal ellenőrizd a már futó mastert. A `scripts/start_feeds.sh` külön `roscore` és rosbridge folyamatot is indít, ezért a jelenlegi systemd-szolgáltatások mellett ne futtasd.
2. **`/cmd_vel` MEGLÉTÉNEK ellenőrzése ELŐSZÖR, mielőtt bármit küldenél:**
   ```bash
   rostopic list | grep cmd_vel
   rostopic info /cmd_vel
   ```
   Ha a topic neve vagy típusa más, mint `geometry_msgs/Twist` a `/cmd_vel` néven, **állj meg** — `base_drive.py` és `control_panel.html` mindkettő ezt a nevet/típust feltételezi, nem megerősítve. Ha eltér, előbb ezt kell javítani a kódban, nem ráerőltetni a robotra.
3. **Fizikai E-stop/kéz a tápkapcsolón.** Valaki álljon a robot mellett úgy, hogy egy mozdulattal le tudja kapcsolni az áramot (barrel jack / battery kapcsoló), mielőtt az első parancs kimegy.
4. **Nyisd meg a helyi vezérlőpultot** a `scripts/start-demo-view.ps1` indítóval (`http://127.0.0.1:8902/scripts/control_panel.html`, ne `file://`), és ellenőrizd, hogy a fejléc „rosbridge: csatlakozva” állapotot mutat. A robot 8901-es weboldala egy régebbi változat.
5. **NE élesíts azonnal.** Előbb figyeld a naplót MOCK módban (élesítés nélkül): a gombnyomások nem küldenek `/cmd_vel` parancsot. Ellenőrizd, hogy az irányok logikusak (előre=x+, balra strafe=y+, stb.).
6. **Első felügyelt bázispróba:** a fizikai leállító mellett álló személlyel, szabad kerekekkel, rendezett kábelekkel kattints az ÉLESÍTÉS gombra, majd csak rövid nyomásokkal próbáld az irányokat. A sebességplafon nem mért hardverhatár.
7. **Megállítás:** a „WEBES MEGÁLLÍTÁS” nulla Twist-et próbál küldeni és leélesít. A hálózat vagy a driver késése miatt ez nem vészleállító: veszély esetén a fizikai leállítót használd. A szóköz nincs megállító billentyűként bekötve.
8. **Karvezérlés valós bekapcsolása NEM ezen a listán van.** Az ízületek URDF-határa ismert, de a 2026-09-19-i darálás és sípolás miatt a kart előbb áramtalanítva fizikailag át kell vizsgálni. A webes karpanel szimuláció marad.

## Amit ez a projekt NEM csinál

- Nem hívja soha az `/camera/toggle_ir` service-t — lásd [07-ismert-hibak.md](07-ismert-hibak.md).
- Nem tesz semmilyen feltételezést a robotkar valós topic-nevéről, üzenettípusáról vagy ízület-sorrendjéről — minden ilyen `arm_control.py`-ban PLACEHOLDER-ként van jelölve.
- Nem indít semmilyen SSH-kapcsolatot magától a robot felé (ezt a session sem tette, mert a robot offline volt).

## Élő ellenőrzés — 2026-09-18, második session (robot elérhető, földön)

A robot ekkor fizikailag a földön volt (nem asztalon — leszedve előtte, hogy egy véletlen `/cmd_vel` ne tudja leejteni), SSH élt (`192.168.123.50`, lásd [09-robot-halozat.md](09-robot-halozat.md)). **Csak olvasó jellegű ellenőrzés történt: roscore + bázis-bringup elindítva, `rostopic`/forráskód-vizsgálat, majd minden folyamat leállítva. Egyetlen mozgás- vagy kar-parancs sem lett élesben elküldve.**

Indított bringup: `roslaunch turn_on_wheeltec_robot turn_on_wheeltec_robot.launch car_mode:=mini_mec_moveit_four` (a `car_mode` értéke a 07-ismert-hibak.md `tf_echo`-javításából volt már ismert). Utána minden ROS-folyamat (`roscore`, `rosmaster`, `rosout`, `wheeltec_robot_node`) leállítva `pkill`-lel — a robot most idle állapotban van.

**Megerősítve:**
- `/cmd_vel` **valós**, `geometry_msgs/Twist`, feliratkozó: `/wheeltec_robot` node. `base_drive.py` és `control_panel.html` feltételezése helyes volt.
- `/arm_cmd` is **valós** (eddig ismeretlen volt) — `std_msgs/Float32MultiArray`, ugyanaz a `/wheeltec_robot` node fogadja (nincs külön MoveIt action-szerver). `wheeltec_robot.cpp` `joint_states_Callback`-jából leolvasva: `data = [j1_rad, j2_rad, j3_rad, gripper_raw]`. A három szög radiánban megy, a firmware-híd ×1000-rel skálázva int16-ba csomagolja — a hívónak radiánt kell adnia. A 2026-09-23-i további vizsgálat a gripper konvencióját is azonosította: `0 = nyitva`, `100 = zárva`.
- Valós ízület-nevek/határok a robot `mini_mec_moveit_four.urdf`-jéből (`turn_on_wheeltec_robot/urdf/`): `j1_joint`, `j2_joint`, `j3_joint` — mindegyik `type="revolute"`, `lower="-0.785" upper="0.785"` (±45°), `effort="100"` (egység nem világos, valószínűleg generikus MoveIt-exportőr alapérték, nem mért adat), `velocity="0"` (nincs megadva — **nem** "korlátlan", ebből sebesség-plafont nem lehet levezetni). A `/joint_states`-ben látott `j4_1_joint..j4_6_joint` egy mechanikusan összekötött gripper-ujj szerelvény, nem külön vezérelhető — az `/arm_cmd` egyetlen `gripper_raw` értéke mozgatja mindet együtt.
- **`arm_control.py` frissítve valós adattal:** `PLACEHOLDER_JOINT_LIMITS_RAD` → `JOINT_LIMITS_RAD`, 4 kitalált érték helyett a 3 URDF-limit (±0.785 rad mindhárom ízületre). A modul **továbbra is mock-only**; a 2026-09-23-i frissítés óta a gripper helyes `0..100` tartományát használja.

**Még nyitva marad — kar valós küldés előtt ez kell:**
1. A daráló/sípoló ízület mechanikai átvizsgálása áramtalanítva.
2. Fizikailag igazolt alaphelyzet és kis, felügyelt egytengelyes mozdulatok, mielőtt automatizált küldő épülne rá.
3. Utána külön kar-élesítésű valós `ArmSender`, amely csak a gombos, korlátozott parancsmodellt engedi ki.

## Nyitott kérdés (bázis) — LEZÁRVA 2026-09-18

`/cmd_vel` léte és típusa élőben megerősítve (lásd fent). A későbbi LAN-kábeles incidens bizonyította, hogy a webes megállításra nem szabad vészleállítóként támaszkodni. Az éles bázispróbához a fenti felügyelt eljárás és a fizikai leállító szükséges.

## Fizikai incidens — 2026-09-18, harmadik session (LAN-port tönkrement)

Bázis-vezérlés élő tesztje közben (webes UI, ÉLESÍTVE) a robot egyik kereke befogta/feltekerte a beépített LAN-portba kötött Ethernet-kábelt. A szoftveres E-STOP gomb (`hardStop()` + `setArmed(false)`, zero Twist publish) **nem állította meg időben a mozgást** — a kábel kitépődött, a beépített LAN-csatlakozó pin-jei eltörtek, a beépített port használhatatlanná vált.

**Következmény/workaround:** a robotra USB-LAN adapter került, ami új interfészt hoz létre (`eth0`, a régi beépített port most `eth1`, `NO-CARRIER`). A meglévő statikus NetworkManager-profil (`192.168.123.50/24`) átvette az új interfészt automatikusan újracsatlakozáskor — külön beavatkozás nem kellett, de ezt validálni kell minden újracsatlakozáskor (`ip a` — melyik interfész van `UP`+`LOWER_UP` állapotban `.50`-es címmel).

**Nyitott biztonsági kérdés, még nincs kivizsgálva:** miért nem állította meg az E-STOP a mozgást időben? Lehetséges okok, egyik sincs megerősítve:
- a `/cmd_vel` publish késleltetve/nem érkezett meg időben a 100ms-es tick-loop és a rosbridge WebSocket felett,
- a mozgás nem is szoftveres `/cmd_vel` parancsból jött ebben a pillanatban, hanem a kábel fizikai feszülése/tekeredése hajtotta tovább a kereket a motor kikapcsolása után is (mechanikai tehetetlenség/behúzás, nem elektronikus hiba),
- vagy a `/wheeltec_robot` node maga nem reagált elég gyorsan egy zero-Twist üzenetre.
Amíg ez nincs tisztázva: **kábelt/laza tárgyat sose hagyj a kerekek közelében élő teszt közben**, és a fizikai E-stop-hoz/tápkapcsolóhoz való hozzáférés (kéz a közelben) kötelező marad minden bázis-teszthez, nem csak a szoftveres gomb.

## Élő ellenőrzés — 2026-09-18, harmadik session (kar, első valódi `/arm_cmd` küldések, felügyelt)

A LAN-javítás után a robot egy stabil, nem-eshető/nem-elgurulható platformon volt rögzítve. Bázis-bringup (`turn_on_wheeltec_robot.launch`) és `rosbridge_websocket` újraindítva (egyik se élt a fizikai incidens/reboot óta). `/wheeltec_robot` node egészséges, `/PowerVoltage` ~21.9V (stabil, nem lemerülés-jel).

**Első valódi `/arm_cmd` küldések ezen a roboton, kézi `rostopic pub -1`-lel, felügyelve (a user fizikailag figyelte a kart):**
- `[0,0,0,0]` — nem történt látható mozgás. **Magyarázat a forráskódból** (`wheeltec_robot.cpp:91-99`): a node csak akkor küld tovább adatot a soros vonalra, ha az új érték >0.01-dal eltér az utolsó elküldött (`last_A/B/C/last_grap`) értéktől — ha ez egyezett a defaulttal, a parancs valószínűleg el sem jutott a szervókig, nem azért nem mozdult semmi, mert már ott volt.
- `[0.15, 0.0, 0.0, 0.0]` (j1 ≈ 8.6°) — elindult, majd **"kiakadt"**: mozgás közben leállt, utána a visszahívás (`[0,0,0,0]`) **sem** mozdította vissza. Feltételezett ok: a szervó saját túlterhelés-/blokkolásvédelme (a driver forráskódja bizonyítottan **sosem** kér vissza pozíciót/hibaállapotot a boardtól — `wheeltec_robot.cpp` csak küld, sosem olvas —, ez a viselkedés a szervó/board saját, ROS-ból láthatatlan szintjén dől el).
- Kb. 1-2 perccel később, power-cycle **nélkül**: `[0.05, 0.0, 0.0, 0.0]` — **ment**, kis mértékben mozdult. A "kiakadás" tehát önmagától old idővel (időzített túlterhelés-timeout jellegű viselkedés), nem szorul fizikai power-cycle-ra.
- `[0.15, 0.0, 0.0, 0.0]` újra (visszatérve a korábban kiakadáshoz vezető célértékhez) — **megint kiakadt**. Vissza `[0.05, 0.0, 0.0, 0.0]`-ra — ment, stabilan ott hagyva a kart.

**Következtetés:** j1 megbízhatóan, mozgás nélküli kiakadás nélkül tesztelve `0`–`0.05` rad tartományban. `0.15` rad körül (a ±0.785 rad URDF-limiten belül, tehát nem szoftveres limit-ütközés) **kétszer is** kiakadt, egyszer viszont (a legelső próbálkozás, más előzmény-állapotból) simán elment volna — ez arra utal, hogy nem egy tiszta, konzisztens mechanikai végállás, hanem valami **időszakos fizikai akadály vagy súrlódás** j1 mozgási útjában valahol 0.05–0.15 rad között. **Mielőtt tovább tesztelnénk j1-et ebben a tartományban: fizikailag át kell nézni, nincs-e kábel/tárgy/mechanikai interferencia a kar forgási útjában.** j2/j3 és a gripper (`data[3]`) még egyáltalán nincs élőben tesztelve.

STM32 board saját natív soros protokollja (ami elvben tudhat Home/torque-enable/hiba-törlés parancsot) **nincs dokumentálva és nincs forráskódja ezen a Jetsonon** — csak a szűk, egyirányú ROS-driver protokoll ismert (`wheeltec_robot.cpp`). Vendor upper-computer/firmware-forrás keresése (ha van ilyen) külön feladat, ha a jövőben mélyebb hozzáférés kell a board-hoz.

**Gyökér-ok azonosítva: lemerült akku.** STM32 board manuális reset után `/PowerVoltage` **17.74V**-ra esett (korábban ~21.9-22.5V stabil volt ugyanabban a sessionben). Ezzel egy időben j2/j3 szervó **teljesen elengedte magát** (kézzel szabadon forgatható, nulla tartónyomaték), miközben j1 még tartotta magát. Ez valószínűleg megmagyarázza a korábbi j1 "kiakadásokat" is (0.15 rad körül, határeset viselkedés) — alacsony feszültségnél a szervók sorban veszítik el a working marginjukat, j1 bírta tovább, j2/j3 már nem. **Interaktív jog-teszt (`arm_jog.py`) eddig csak j1-en lett érdemben kipróbálva** (q/a billentyűk) — j2/j3 (w/s, e/d) tesztje az akku-lemerülés miatt félbeszakadt, folytatás töltés után szükséges. Robot most töltőn.

## Automatikus indítás (systemd) — 2026-09-18

Kolléga-teszteléshez a robot mindent magától elindít bekapcsoláskor: `pickerbot-bringup` (bázis-driver) → `pickerbot-rosbridge` (9090, függ a bringup-tól) → `pickerbot-webui` (8901-es `http.server`, `/home/wheeltec/pickerbot_web_ui/`). Unit fájlok: `/etc/systemd/system/pickerbot-*.service` a roboton (nincsenek ebben a repóban verziózva, csak a roboton élnek). Mind `enable`-ölve, `Restart=on-failure`. Kolléga csak a robot-hálóra csatlakozik, és megnyitja `http://192.168.123.50:8901/control_panel.html`-t — SSH nem kell.

## Kézi jog-eszköz kar-teszthez

[`/home/wheeltec/arm_jog.py`](robot, nincs repóban) — interaktív terminál-script, `rospy` + nyers billentyű-olvasás (`termios`/`tty`), csak j1/j2/j3-at mozgatja, gripper (`data[3]`) mindig `0.0`. Billentyűk: `q`/`a` = j1 +/-, `w`/`s` = j2 +/-, `e`/`d` = j3 +/-, `+`/`-` = lépésköz (alap 0.02 rad), `x` = kilépés. Induló pozíció `[0.05, 0.0, 0.0]` (utolsó ismert biztonságos j1-érték ebből a sessionből).

Futtatás (Windows terminálból, `-t` kötelező a pty-allokációhoz):
```
ssh -t -i ~/.ssh/pickerbot_mini wheeltec@192.168.123.50 "source /opt/ros/noetic/setup.bash; python3 /home/wheeltec/arm_jog.py"
```

## 2026-09-19: joystickkel előidézett karhiba, újraindítás után is

A felhasználó szerint a robot földre helyezése után a korábban lelógó kar nem emelkedett fel a várt helyzetbe. A fizikai joystick egyik irányában a kar a mechanikai határon túl akar menni: daráló hang és sípolás hallatszik. Ezután a fel-le irányú mozgás nem normális; újraindítás után is jelentkezik. A felhasználó a talp fölötti első fel-le ízületet gyanítja, de a pontos hajtás még nincs azonosítva. A hang önmagában nem bizonyít fogaskeréksérülést; túlterhelés, elakadás, elállított nullpont vagy sérült hajtás egyaránt nyitott lehetőség. **További joystick- és ROS-karpróbát ne végezzünk, amíg az érintett ízületet áramtalanítva meg nem vizsgáltuk.** A kart alá kell támasztani, a hajtást nem szabad erővel átforgatni.

Olvasó jellegű vizsgálat történt, mozgásparancs nélkül:

- Az újraindítás utáni `/PowerVoltage` érték **25,131 V** volt. A 2026-09-18-i 17,74 V-os lemerülés tehát a mostani jelenséget önmagában nem magyarázza.
- A `/arm_cmd` típusa `std_msgs/Float32MultiArray`; egyetlen feliratkozója a `/wheeltec_robot`, **nincs ROS-publikálója**. A Jetsonon nem fut `joy` vagy kar-teleop node, és nem látszik `/dev/input/js*`. Ez alapján a használt fizikai joystick valószínűleg közvetlenül az alsó vezérlőhöz kapcsolódik; ezt a kábelezés/vevőegység fizikai ellenőrzése igazolhatja. A webes vezérlés szoftveres korlátozása ezt a joystick-utat nem védené.
- A `/joint_states` üzenetben minden pozíció nulla, publikálója a gyári `joint_state_publisher`. Ez modellállapot, **nem mért szervópozíció**; ebből nem tudható, hol van ténylegesen a kar. A gyári `wheeltec_robot.cpp` `/arm_cmd` callbackje három célértéket továbbít soros vonalon, valós ízületpozíciót és szervóhibát nem publikál.
- A `wheeltec_robot.cpp` destruktora szabályos leálláskor a bázisnak nulla sebességet, majd a karnak `[0, 1.5707, 0.3917, 0]` célt küld. A második ízület 1,5707 rad célja nagyobb, mint a betöltött `mini_mec_moveit_four.urdf` ±0,785 rad határa. Nem bizonyított, hogy a robot újraindításakor ez a kódrész ténylegesen végrehajtódott, illetve hogy a modellhatár megfelel-e a fizikai határnak. Emiatt **ne állítsuk le vagy indítsuk újra próbaképpen a bringupot** a kar mechanikai ellenőrzése előtt. A gyári fájlt nem módosítottuk.
- A régi `/home/wheeltec/arm_jog.py` induláskor azonnal elküldi a `[0.05, 0, 0, 0]` célt, miközben a valós kezdőpozíciót nem tudja lekérdezni. Ezt az eszközt most ne indítsuk el.

Ez a 2026-09-19-i megállapítás történeti állapot. A felhasználó 2026-09-23-án kezelői felügyelettel kérte az élő bekötést; a `control_panel.html` azóta külön kar-élesítéssel, kis lépéses gombokkal és billentyűkkel publikál a `/arm_cmd` témára.

A teljesítményről ugyanebben a vizsgálatban: a C70 ROS-forrása kb. 15 kép/s sebességgel publikált, míg a `/map` kb. 0,8–1 üzenet/s sebességgel frissült. A laptop helyi MJPEG-alagútja nem válaszolt, ezért a dashboard a nagyobb késleltetésű nyers ROS-képet használta. A `pickerbot-slam` konténer kb. 32% CPU-t használt, 5,2 GiB memória rendelkezésre állt. A kamera megjelenítési késése és a térkép frissítési sebessége külön optimalizálási feladat; nem magyarázza a kar mechanikai hangját.
