# C70 kamera és helyi videófolyam

Ez a Docker-kép a robot meglévő ROS masteréhez csatlakozik. Nem indít új mastert, alvázdrivert vagy LiDAR-t. A `start-c70.sh` a `/dev/RgbCam` eszközről publikál a `/usb_cam/image_raw` témára. A kamera USB-bemenete 640×480/30 fps MJPEG; ez tehermentesíti az Astrával közös USB 2.0 buszt. A `start-web-video.sh` a 8080-as porton szolgálja ki a képet, de csak a robot `127.0.0.1` címén. Mindkét indító legfeljebb 60 másodpercig vár a ROS master `/run_id` paraméterére.

Az image-et **a roboton** építsd, mert a Jetson ARM64-es. A mappa három futtatáshoz szükséges fájlját (`Dockerfile`, `start-c70.sh`, `start-web-video.sh`) másold a robot `/home/wheeltec/pickerbot-c70-build-20260919/` mappájába, majd:

```bash
sudo docker build -t pickerbot/c70:noetic-20260923-mjpeg /home/wheeltec/pickerbot-c70-build-20260919
```

2026-09-19-én a két alábbi konténer már létrejött. Csak akkor futtasd újra a parancsokat, ha a konténerek nem léteznek; előbb ellenőrizd a `sudo docker ps -a` kimenetét. Az eredeti indításkor a `/dev/video0` felelt meg a robot `/dev/RgbCam` szimbolikus linkjének.

```bash
sudo docker run -d --restart unless-stopped --name pickerbot-c70 --network host \
  --device /dev/video0:/dev/RgbCam \
  -e ROS_MASTER_URI=http://192.168.123.50:11311 -e ROS_IP=192.168.123.50 \
  pickerbot/c70:noetic-20260923-mjpeg

sudo docker run -d --restart unless-stopped --name pickerbot-web-video --network host \
  -e ROS_MASTER_URI=http://192.168.123.50:11311 -e ROS_IP=192.168.123.50 \
  --entrypoint /usr/local/bin/start-web-video pickerbot/c70:noetic-20260919
```

**USB-újraazonosítás után:** 2026-09-19 11:50-kor a C70 USB-eszköz levált, majd `/dev/video1` néven tért vissza. A Docker `--device /dev/video0:/dev/RgbCam` hozzárendelése a régi eszközre maradt; a `pickerbot-c70` kilépett `VIDIOC_DQBUF error 19, No such device` hibával. A `--restart unless-stopped` önmagában nem köti át új eszközre. A roboton a `readlink -f /dev/RgbCam` értékét ellenőrizd, majd a repó [recover-c70.sh](recover-c70.sh) szkriptjét futtasd `sudo`-val. Ez csak a `pickerbot-c70` konténert hozza létre újra az aktuális `/dev/videoN` eszközzel, és csak friss ROS-képkocka után távolítja el a korábbi példányt. A web-video, LiDAR, SLAM és alváz szolgáltatásokhoz nem nyúl. Ha az USB leválás ismétlődik, a kábel/USB-hub/tápellátás fizikai okát is meg kell keresni; a szkript csak a szoftveres helyreállítást végzi.

Ellenőrzés a roboton: `rostopic hz /usb_cam/image_raw`, `ss -ltn | grep :8080`. A portnak csak `127.0.0.1:8080` címen szabad figyelnie. A laptopon a `scripts/start-demo-view.ps1` indítja a helyi irányítópultot és az SSH-alagutat; a `scripts/stop-demo-view.ps1` csak ezeket a helyi segédfolyamatokat állítja le. A robot konténereinek leállításához:

```bash
sudo docker stop pickerbot-web-video pickerbot-c70
sudo docker rm pickerbot-web-video pickerbot-c70
```

A gyári ROS-fájlok és a három meglévő systemd-szolgáltatás nem változtak. A 2026-09-19-i robot-reboot után a `pickerbot-c70` konténer újraindulási körbe került és nem publikált képet, bár `/dev/RgbCam` újra `/dev/video0`-ra mutatott. A `recover-c70.sh` a konténert újra létrehozta, és friss ROS-képkockát igazolt. Tehát a Docker automatikus restartja önmagában nem bizonyult elégségesnek; a reboot utáni kameraképet külön ellenőrizni kell. A LiDAR/SLAM konténerek futottak, a `/map` publikálója visszatért. Az USB-leválás hardveres okát külön kell megkeresni.

**2026-09-23:** a C70 az új `pickerbot/c70:noetic-20260923-mjpeg` image-ből fut. A YUYV helyett használt MJPEG csökkenti az Astrával közös USB 2.0 busz terhelését. A `pickerbot-sensors-recover.service` ROS master után, az Astra mögött indítja a C70-et, majd ellenőrzi a friss képkockát. Tiszta robot-reboot után a C70 és az Astra RGB képe egyszerre működött; részletek: [../../docs/12-szenzor-inditasi-sorrend.md](../../docs/12-szenzor-inditasi-sorrend.md).
