#!/usr/bin/env bash
# Re-register Docker-backed sensors after the real ROS master is ready.
set -eo pipefail

if (( EUID != 0 )); then
  echo 'pickerbot-sensors-recover must run as root.' >&2
  exit 1
fi

source /opt/ros/noetic/setup.bash
set -u
export ROS_MASTER_URI=${ROS_MASTER_URI:-http://127.0.0.1:11311}

wait_for_master() {
  local attempt
  for attempt in {1..60}; do
    rosparam get /run_id >/dev/null 2>&1 && return 0
    sleep 1
  done
  echo 'ROS master did not publish /run_id within 60 seconds.' >&2
  return 1
}

wait_for_topic() {
  local topic=$1
  local attempts=${2:-15}
  local attempt
  for attempt in $(seq 1 "$attempts"); do
    timeout 2 rostopic echo -n 1 "$topic" >/dev/null 2>&1 && return 0
  done
  echo "No fresh message received from $topic." >&2
  return 1
}

require_container() {
  docker container inspect "$1" >/dev/null 2>&1 || {
    echo "Required Docker container is missing: $1" >&2
    return 1
  }
}

wait_for_master
for container in pickerbot-lidar pickerbot-c70 pickerbot-web-video pickerbot-slam; do
  require_container "$container"
done

# The two cameras share one USB 2.0 bus. Give Astra RGB-D the bus first, then
# start the C70 in compressed MJPEG mode.
docker stop pickerbot-c70 >/dev/null 2>&1 || true
if ! wait_for_topic /camera/depth/image_raw/header 3 || \
   ! wait_for_topic /camera/rgb/image_raw/header 3; then
  echo 'Restarting Astra after ROS master startup and with C70 stopped.'
  systemctl restart pickerbot-camera.service
  wait_for_topic /camera/depth/image_raw/header 15
fi

if wait_for_topic /camera/rgb/image_raw/header 8; then
  echo 'Astra RGB stream is healthy.'
else
  echo 'WARNING: Astra depth works, but RGB still has no frames. Check its USB cable/port.' >&2
fi

echo 'Restarting LiDAR after ROS master startup.'
docker restart pickerbot-lidar >/dev/null
wait_for_topic /scan/header 15

c70_device=$(readlink -f /dev/RgbCam || true)
c70_mapped=$(docker inspect --format '{{range .HostConfig.Devices}}{{.PathOnHost}}{{end}}' pickerbot-c70)
if [[ ! $c70_device =~ ^/dev/video[0-9]+$ || ! -c $c70_device ]]; then
  echo "C70 device is unavailable: $c70_device" >&2
  exit 1
fi
if [[ $c70_mapped != "$c70_device" ]]; then
  echo "C70 moved from $c70_mapped to $c70_device; recreating its device mapping."
  /usr/local/sbin/pickerbot-recover-c70
else
  docker start pickerbot-c70 >/dev/null
fi
wait_for_topic /usb_cam/image_raw/header 15

echo 'Restarting local MJPEG relay after C70.'
docker restart pickerbot-web-video >/dev/null

echo 'Restarting SLAM after LiDAR.'
docker restart pickerbot-slam >/dev/null
wait_for_topic /map/info 20

echo 'Pickerbot sensor startup check completed.'
