#!/usr/bin/env bash
set -euo pipefail
source /opt/ros/noetic/setup.bash
: "${ROS_MASTER_URI:?Set ROS_MASTER_URI to the running robot master}"
: "${ROS_IP:?Set ROS_IP to the robot address}"
for attempt in {1..60}; do
  if rosparam get /run_id >/dev/null 2>&1; then
    break
  fi
  sleep 1
done
rosparam get /run_id >/dev/null

profile="${GMAPPING_PROFILE:-baseline}"
case "$profile" in
  baseline) launch_file=/opt/pickerbot/gmapping.launch ;;
  tuned) launch_file=/opt/pickerbot/gmapping-tuned.launch ;;
  *)
    echo "Unknown GMAPPING_PROFILE: $profile (expected baseline or tuned)" >&2
    exit 64
    ;;
esac

echo "Pickerbot SLAM profile: $profile ($launch_file)"
exec roslaunch "$launch_file"
