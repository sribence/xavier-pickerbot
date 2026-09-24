# Kar- és grippervezérlés — műszaki állapot

Utolsó kódellenőrzés: 2026-09-24. A folyamatos vezérlés ellenőrzése során kar- vagy gripperparancs nem ment ki.

## Biztosan ismert vezérlési lánc

- ROS topic: `/arm_cmd`
- Üzenettípus: `std_msgs/Float32MultiArray`
- Adatsorrend: `[j1_rad, j2_rad, j3_rad, gripper]`
- A három ízületi cél radiánban kerül a driverhez, amely ezerszeres skálázással küldi az STM32-nek.
- A gripper gyári tartománya `0..100`: `0 = nyitva`, `100 = zárva`; a gyári kézi vezérlő 5-ös lépést használ.
- A `/wheeltec_robot` az egyetlen `/arm_cmd` feliratkozó.

Források a roboton:

- `/home/wheeltec/wheeltec_robot/src/turn_on_wheeltec_robot/src/wheeltec_robot.cpp`
- `/home/wheeltec/wheeltec_robot/src/stepper_arm/src/stepper_motor_arm.cpp`
- `/home/wheeltec/wheeltec_robot/src/stepper_arm/src/robot_keyboard_control.cpp`
- `/home/wheeltec/wheeltec_robot/src/stepper_arm/src/auto_pick_colorBlock.cpp`

## Miért nem használható biztonságosan abszolút csúszka

Az STM32 24 bájtos visszajelző csomagja csak az alváz sebességét, IMU-adatot és akkufeszültséget tartalmaz. Valódi karpozíciót vagy szervóhibát nem ad. A ROS `/joint_states` karértékei modellből származó nullák, nem mért értékek.

Minden `/arm_cmd` üzenet egyszerre tartalmazza mindhárom kartengelyt és a grippert. Ezért a gripper sem vezérelhető önmagában: rosszul feltételezett ízületi értékek mellett egy nyitás vagy zárás is váratlan karmozgást indíthat.

A csúszka abszolút célt állítana be úgy, hogy a weboldal nem ismeri a valós kezdőpozíciót. Emiatt a csúszkás élő vezérlés ezen a hardveren visszajelzés vagy igazolt alaphelyzet nélkül nem biztonságos.

## Gyári kinematikai modell

A `stepper_motor_arm.cpp` a következő korlátokat használja:

| Elem | Tartomány / érték |
|---|---|
| j1 | `-1,9 .. +1,9 rad` |
| j2 | `-0,17 .. +1,5708 rad` |
| j3 | `0,3918 .. 2,2981 rad` |
| Kapcsolt feltétel | `j2 + j3 >= π/2` |
| Felkar | `0,14 m` |
| Alkar | `0,16 m` |
| Gyári kar-lépés | `0,02 rad` |
| Gyári karvég-lépés | `0,01 m` |
| Gyári gripper-lépés | `5` |

A gyári modell ezen felül öt körívvel korlátozza a karvég munkaterét. Ezek a korlátok bekerültek a webes szimulációba.

Az URDF mindhárom ízületre ±0,785 rad határt tartalmaz, ami eltér a gyári `stepper_arm` vezérlő modelljétől. Ezt az ellentmondást élő vezérlés előtt fizikailag kell tisztázni; egyik tartományt sem szabad automatikusan mechanikai végállásként kezelni.

## Elkészült élő webes felület

A [control_panel.html](../scripts/control_panel.html) karpanelje:

- eltávolította az abszolút szögcsúszkákat;
- talp balra/jobbra gombot ad 0,02 rad lépéssel;
- a karvéget előre/hátra/fel/le mozgatja 1 cm-es lépéssel;
- ellenőrzi a gyári inverz kinematikát, ízületi és munkatérkorlátokat;
- a grippert 5-ös lépésekben vezérli a valós `0..100` skálán;
- külön `KAR ÉLESÍTÉS` gombot használ, a bázis élesítésétől függetlenül;
- élesítés után a rövid kattintás vagy billentyűlenyomás egy finom `/arm_cmd` lépést küld;
- nyomva tartáskor ugyanazt a finom lépést 100 ms-onként ismétli;
- elengedés, elveszett billentyű-heartbeat (850 ms), fókuszvesztés, háttérbe kerülő oldal, ROS-kapcsolatvesztés, munkatér- vagy gripperhatár és a 15 másodperces kemény időkorlát leállítja az ismétlést;
- oldalbetöltéskor, újracsatlakozáskor és a parancsmodell visszaállításakor nem küld automatikus karcélt.

Billentyűzet:

| Billentyű | Művelet |
|---|---|
| `C` / `V` | talp balra / jobbra |
| `R` / `F` | karvég előre / hátra |
| `T` / `G` | karvég fel / le |
| `H` / `J` | gripper nyit / zár |

A billentyű ismétlődő `keydown` eseményei heartbeatként igazolják, hogy a billentyű még le van nyomva. Ha 850 ms-ig nem érkezik új jel, a mozgás keyup nélkül is leáll. Rövid lenyomás egy lépés; nyomva tartás folyamatos finom mozgás.

Az [arm_control.py](../scripts/xavier_control/arm_control.py) mock sender grippermodellje szintén a valós `0..100` tartományra frissült. A Python modul továbbra sem importál ROS-klienskönyvtárat és nem tud élő parancsot küldeni.

## Élő használat

1. Nyisd meg a `control_panel.html` oldalt, és ellenőrizd a `rosbridge: csatlakozva` állapotot.
2. A karpanel `KAR ÉLESÍTÉS` gombjával külön élesítsd a kart.
3. Kattints vagy üsd le röviden a billentyűt egy kis lépéshez; tartsd nyomva a folyamatos finom mozgáshoz.
4. A `Parancsmodell alaphelyzetbe` gomb csak a böngésző célállapotát állítja vissza, nem mozgatja a robotot.
5. Leélesítéshez kattints a `KAR LEÉLESÍTÉS` gombra. A bázis webes megállítása nem változtatja a kar célhelyzetét.

A parancsmodell induló értéke `[0, 1.570796, 0.391797, 0]`. Mivel nincs mért ízületi visszajelzés, az első parancs is ebből a gyári alaphelyzetből számított célt küld. A felhasználó kérésére a kezelő fizikailag figyeli a kart.

## Átadási állapot

A gombos kezelőfelület, a korlátozó modell, a külön kar-élesítés, a `/arm_cmd` publisher és a billentyűzetes vezérlés elkészült. A robotra telepített 8901-es oldal és a helyi 8902-es fejlesztői oldal ugyanazt a fájlt használja a telepítés után. A régi `/home/wheeltec/arm_jog.py` használata nem szükséges.
