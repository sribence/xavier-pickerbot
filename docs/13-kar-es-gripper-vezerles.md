# Kar- és grippervezérlés — műszaki állapot

Utolsó ellenőrzés: 2026-09-23. A vizsgálat olvasó jellegű volt; kar- vagy gripperparancs nem ment ki.

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

## Elkészült webes felület

A [control_panel.html](../scripts/control_panel.html) karpanelje:

- eltávolította az abszolút szögcsúszkákat;
- talp balra/jobbra gombot ad 0,02 rad szimulált lépéssel;
- a karvéget előre/hátra/fel/le mozgatja 1 cm-es szimulált lépéssel;
- ellenőrzi a gyári inverz kinematikát, ízületi és munkatérkorlátokat;
- a grippert 5-ös lépésekben szimulálja a valós `0..100` skálán;
- jól láthatóan jelzi, hogy az élő vezérlés zárolva van;
- nem hoz létre `/arm_cmd` publishert és nem küld parancsot a robotnak.

Az [arm_control.py](../scripts/xavier_control/arm_control.py) mock sender grippermodellje szintén a valós `0..100` tartományra frissült. A Python modul továbbra sem importál ROS-klienskönyvtárat és nem tud élő parancsot küldeni.

## Az élő bekapcsolás szükséges sorrendje

1. A daráló/sípoló fel-le ízületet áramtalanítva mechanikailag át kell vizsgálni.
2. Meg kell határozni egy reprodukálható fizikai alaphelyzetet, amelyhez ismert numerikus j1/j2/j3 cél tartozik.
3. Fizikai leállításra kész kezelő mellett, megtámasztott karral egyenként kell igazolni a mozgásirányokat 0,02 rad lépéssel.
4. Ellenőrizni kell a gyári kód és az URDF eltérő határait a valódi mechanikai tartományhoz képest.
5. Csak ezután készülhet külön kar-élesítésű `/arm_cmd` publisher. A weboldal betöltése, ROS-újracsatlakozás vagy bázisélesítés nem küldhet automatikus karcélt.
6. A gripper első élő próbája is csak a kar célállapotának szinkronizálása után történhet.

## Átadási állapot

A gombos kezelőfelület és a korlátozó modell elkészült és offline ellenőrizhető. Az élő vezérlés szándékosan nincs bekapcsolva. A következő ágens ne adjon ki `/arm_cmd` üzenetet, és ne indítsa el a roboton maradt régi `/home/wheeltec/arm_jog.py` fájlt addig, amíg a mechanikai ellenőrzés és az alaphelyzet igazolása nem történt meg.
