#!/bin/sh
# NetworkManager dispatcher: keep the ROS address on the wired link when it
# exists; move it to the already connected USB Wi-Fi link when Ethernet drops.
set -eu

ETH=eth0
WIFI=wlan1
ROS_ADDRESS=192.168.123.50
WIFI_ADDRESS=192.168.123.51

case "${1:-}:${2:-}" in
    "$ETH":pre-up|"$ETH":up|"$ETH":down|"$WIFI":up|"$WIFI":down) ;;
    *) exit 0 ;;
esac

has_address() {
    ip -4 -o addr show dev "$1" | grep -q " $2/"
}

remove_wifi_alias() {
    if has_address "$WIFI" "$ROS_ADDRESS"; then
        ip addr del "$ROS_ADDRESS/32" dev "$WIFI"
    fi
}

# Remove the alias before the wired profile finishes activating, avoiding a
# persistent duplicate .50 address on two interfaces.
if [ "$1:$2" = "$ETH:pre-up" ]; then
    remove_wifi_alias
    exit 0
fi

if [ "$(cat /sys/class/net/$ETH/carrier 2>/dev/null || echo 0)" = 1 ] &&
   has_address "$ETH" "$ROS_ADDRESS"; then
    remove_wifi_alias
elif [ "$(cat /sys/class/net/$WIFI/carrier 2>/dev/null || echo 0)" = 1 ] &&
     has_address "$WIFI" "$WIFI_ADDRESS"; then
    if ! has_address "$WIFI" "$ROS_ADDRESS"; then
        ip addr add "$ROS_ADDRESS/32" dev "$WIFI"
    fi
else
    remove_wifi_alias
fi
