# Szenzorok stabil indulása és a két kamera USB-terhelése

**Dátum:** 2026-09-23  
**Érintett elemek:** C70 kamera, Orbbec Astra S RGB-D kamera, M10P LiDAR, gmapping

## Végeredmény

**Telepítve és tiszta robot-reboot után igazolva 2026-09-23-án.** A reboot után automatikusan aktív lett a `pickerbot-bringup`, `pickerbot-camera`, `pickerbot-rosbridge`, `pickerbot-webui` és `pickerbot-sensors-recover`. Friss üzenet érkezett az `/odom`, `/camera/depth/image_raw`, `/camera/rgb/image_raw`, `/usb_cam/image_raw`, `/scan` és `/map` témán. A bemutatóoldalon a C70 és a hátsó RGB kis- és nagy nézete is élő képet adott.

## Tünet

Tiszta robotindítás után az `/odom` és az Astra mélységi képe rendszeresen elindult, miközben a következő adatfolyamok hiányoztak:

- `/scan`
- `/map`
- `/usb_cam/image_raw`
- `/camera/rgb/image_raw`

A folyamatok egy része közben látszólag futott. Emiatt a hiba nem a bemutatóoldal HTML-kódjában volt.

## Igazolt okok

### 1. A Docker-konténerek a ROS master előtt indultak

A `pickerbot-lidar`, `pickerbot-c70` és `pickerbot-slam` konténert a Docker `unless-stopped` szabálya már a boot elején elindította. A `pickerbot-bringup` által létrehozott valódi ROS master csak később állt fel. A konténerek folyamatai ezért futottak, de nem regisztráltak a használható ROS masterhez.

Az okot sorrendi, kézi helyreállítás igazolta:

1. `pickerbot-lidar` újraindítása után a `/scan` kb. 12 Hz-cel megjelent.
2. `pickerbot-c70` újraindítása után a `/usb_cam/image_raw` kb. 30 Hz-cel megjelent.
3. `pickerbot-slam` újraindítása után a `/map` újra publikált.

A LiDAR és a C70 root folyamatainak forrása tehát nem udev-szabály: Docker-konténerek indítják őket.

### 2. A kamera systemd-szolgáltatása csak folyamatindításra várt

A `pickerbot-camera.service` ugyan `After=` és `Requires=` kapcsolatban állt a bringuppal, de a bringup `Type=simple`. A systemd ezért már a bringup folyamatának elindítását késznek tekintette, amikor a ROS master még nem feltétlenül publikálta a `/run_id` paramétert. A kamera naplójában emiatt saját master indítási kísérlet, eltérő `run_id` és portütközés is látszott.

A javított egység indítás előtt legfeljebb 60 másodpercig vár a valódi `/run_id` megjelenésére.

### 3. A két kamera ugyanazon az USB 2.0 buszon van

A felhasználó egy laza USB-aljzat miatt áthelyezte az egyik csatlakozót. Az aktuális USB-fa szerint ezután mindkét kamera ugyanazon a 480 Mbit/s-os ágon jelent meg:

- Astra S: `2bc5:0402`, 480 Mbit/s
- C70: `0bda:3031`, 480 Mbit/s

A C70 eddig 640×480, 30 fps, tömörítetlen YUYV módot használt. Az Astra mélységi és színes adatfolyamával együtt ez túl közel kerül az USB 2.0 gyakorlati határához. A C70 hardvere ugyanebben a felbontásban és képkockasebességgel támogatja a tömörített MJPEG módot, ezért az új indító ezt használja.

Az Astra saját azonosítása `Orbbec Astra S`; a driver támogatott színes módokat jelent. A naplóban korábban látható `No color sensor found or transition is invalid` és a képkockák hiánya a jelenlegi USB-helyzettel függött össze. A C70 MJPEG-re váltása és a sorrendi kameraindítás után az Astra RGB képe reboot után is elindult.

## Elkészített tartós javítás

- `systemd/pickerbot-camera.service`
  - megvárja a `/run_id` paramétert;
  - rögzíti a helyi ROS master címét;
  - bringup újraindításakor vele együtt újraindul.
- `systemd/pickerbot-sensors-recover.service`
  - a bringup és a kamera után fut;
  - a szenzorokat egymás után indítja, minden lépés után friss ROS-üzenetet vár;
  - előbb az Astrát engedi felállni, utána indítja a C70-et;
  - LiDAR után indítja a gmappinget;
  - kezeli, ha a C70 `/dev/videoN` sorszáma megváltozott.
- `systemd/pickerbot-sensors-recover.sh`
  - a fenti sorrend és ellenőrzések végrehajtója.
- `docker/sensors/start-c70.sh`
  - YUYV helyett MJPEG bemenetet használ 640×480/30 fps mellett.
- `docker/sensors/recover-c70.sh`
  - az új `pickerbot/c70:noetic-20260923-mjpeg` image-ből állítja helyre a konténert.

## Alkalmazott telepítési menet

A telepítés rövid időre újraindította a kamera-, LiDAR- és SLAM-folyamatokat. Mozgásparancs nem ment ki.

1. Másold a `docker/sensors/` buildfájljait a robotra, majd építsd meg ARM64-en a `pickerbot/c70:noetic-20260923-mjpeg` image-et.
2. Nevezd át biztonsági mentésnek a jelenlegi `pickerbot-c70` konténert, és az új image-ből hozd létre az azonos nevű példányt.
3. Másold a két helyreállító szkriptet `/usr/local/sbin/` alá, végrehajtható jogosultsággal.
4. Másold a két systemd egységet `/etc/systemd/system/` alá.
5. `systemctl daemon-reload`, majd engedélyezd és indítsd a `pickerbot-sensors-recover.service` egységet.
6. Csak az összes ellenőrzés sikeres lefutása után töröld a régi C70 konténer biztonsági példányát.

## Elvégzett ellenőrzés

Telepítés után és egy külön tiszta reboot után is friss üzenet érkezett ezeken:

```text
/odom
/camera/depth/image_raw
/camera/rgb/image_raw
/usb_cam/image_raw
/scan
/map
```

A bemutatóoldalon külön ellenőrizendő a C70 kép, a hátsó RGB kép, a mélység és a térkép. A javítás közben nem kell és nem szabad mozgásparancsot kiadni.

## Visszaállítás

Ha az MJPEG C70 nem publikál:

1. állítsd le és töröld az új `pickerbot-c70` konténert;
2. nevezd vissza a biztonsági példányt `pickerbot-c70` névre és indítsd el;
3. tiltsd le a `pickerbot-sensors-recover.service` egységet;
4. állítsd vissza a korábbi `pickerbot-camera.service` fájlt a Gitből;
5. futtasd a `systemctl daemon-reload` parancsot.

Az Astra USB-eszközének szoftveres resetje nincs beépítve az automatikus indításba. Ilyet csak külön diagnosztikai lépésként, kizárólag az Astra azonosítása után szabad végezni.
