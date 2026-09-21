#!/bin/sh
# NetworkManager dispatcher: keep the ROS address on the wired link when it
# exists; prefer the built-in Wi-Fi client, then the USB Wi-Fi link.
set -eu

ETH=eth0
ONBOARD=wlan0
USB_WIFI=wlan1
ROS_ADDRESS=192.168.123.50
ONBOARD_ADDRESS=192.168.123.52
USB_WIFI_ADDRESS=192.168.123.51

case "${1:-}:${2:-}" in
    "$ETH":pre-up|"$ETH":up|"$ETH":down|\
    "$ONBOARD":up|"$ONBOARD":down|"$USB_WIFI":up|"$USB_WIFI":down) ;;
    *) exit 0 ;;
esac

has_address() {
    ip -4 -o addr show dev "$1" 2>/dev/null | grep -q " $2/"
}

has_carrier() {
    [ "$(cat "/sys/class/net/$1/carrier" 2>/dev/null || echo 0)" = 1 ]
}

remove_alias() {
    if has_address "$1" "$ROS_ADDRESS"; then
        ip addr del "$ROS_ADDRESS/32" dev "$1"
    fi
}

# Remove the alias before the wired profile finishes activating, avoiding a
# persistent duplicate .50 address on two interfaces.
if [ "$1:$2" = "$ETH:pre-up" ]; then
    remove_alias "$ONBOARD"
    remove_alias "$USB_WIFI"
    exit 0
fi

if has_carrier "$ETH" && has_address "$ETH" "$ROS_ADDRESS"; then
    remove_alias "$ONBOARD"
    remove_alias "$USB_WIFI"
elif has_carrier "$ONBOARD" && has_address "$ONBOARD" "$ONBOARD_ADDRESS"; then
    remove_alias "$USB_WIFI"
    if ! has_address "$ONBOARD" "$ROS_ADDRESS"; then
        ip addr add "$ROS_ADDRESS/32" dev "$ONBOARD"
    fi
elif has_carrier "$USB_WIFI" && has_address "$USB_WIFI" "$USB_WIFI_ADDRESS"; then
    remove_alias "$ONBOARD"
    if ! has_address "$USB_WIFI" "$ROS_ADDRESS"; then
        ip addr add "$ROS_ADDRESS/32" dev "$USB_WIFI"
    fi
else
    remove_alias "$ONBOARD"
    remove_alias "$USB_WIFI"
fi
