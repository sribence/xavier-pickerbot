#!/usr/bin/env bash
# Recreate only the C70 container after a USB reconnect changes /dev/videoN.
set -euo pipefail

if (( EUID != 0 )); then
  echo 'Run this script with sudo on the robot.' >&2
  exit 1
fi

device=$(readlink -f /dev/RgbCam)
if [[ ! $device =~ ^/dev/video[0-9]+$ || ! -c $device ]]; then
  echo "C70 device is unavailable: $device" >&2
  exit 1
fi

backup=''
if docker container inspect pickerbot-c70 >/dev/null 2>&1; then
  mapped=$(docker inspect --format '{{range .HostConfig.Devices}}{{.PathOnHost}}{{end}}' pickerbot-c70)
  running=$(docker inspect --format '{{.State.Running}}' pickerbot-c70)
  if [[ $mapped == "$device" && $running == true ]]; then
    echo "C70 container already runs with $device"
    exit 0
  fi
  backup="pickerbot-c70-backup-$(date +%s)-$$"
  docker stop pickerbot-c70 >/dev/null
  docker rename pickerbot-c70 "$backup"
fi

restore_on_error() {
  code=$?
  if (( code != 0 )); then
    docker rm -f pickerbot-c70 >/dev/null 2>&1 || true
    if [[ -n $backup ]]; then docker rename "$backup" pickerbot-c70; fi
  fi
  exit "$code"
}
trap restore_on_error EXIT

docker run -d --restart unless-stopped --name pickerbot-c70 --network host \
  --device "$device:/dev/RgbCam" \
  -e ROS_MASTER_URI=http://192.168.123.50:11311 -e ROS_IP=192.168.123.50 \
  pickerbot/c70:noetic-20260919 >/dev/null

set +u
source /opt/ros/noetic/setup.bash
set -u
if ! timeout 15 rostopic echo -n 1 /usb_cam/image_raw/header >/dev/null; then
  echo 'The new C70 container started but did not publish an image; restoring the previous container.' >&2
  exit 1
fi

if [[ -n $backup ]]; then docker rm "$backup" >/dev/null; fi
trap - EXIT
echo "C70 recovered: $device, fresh /usb_cam/image_raw frame received."
