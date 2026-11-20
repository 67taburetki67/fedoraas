#!/usr/bin/env bash
w=$(nmcli radio wifi 2>/dev/null)
[ "$w" = "enabled" ] && echo "wifi=on" || echo "wifi=off"
echo "ssid=$(nmcli -t -e no -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1=="yes"{sub(/^yes:/,""); print; exit}')"
bluetoothctl show 2>/dev/null | grep -q 'Powered: yes' && echo "bt=on" || echo "bt=off"
echo "btdev=$(bluetoothctl devices Connected 2>/dev/null | head -1 | cut -d' ' -f3-)"
v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null)
echo "vol=$(echo "$v" | awk '{printf "%.0f", $2*100}')"
echo "$v" | grep -q MUTED && echo "muted=yes" || echo "muted=no"
echo "bri=$(brightnessctl -m 2>/dev/null | head -1 | cut -d, -f4 | tr -d '%')"
echo "profile=$(powerprofilesctl get 2>/dev/null || echo none)"
if rfkill list all 2>/dev/null | grep -q 'Soft blocked' && ! rfkill list all 2>/dev/null | grep -q 'Soft blocked: no'; then
  echo "airplane=yes"
else
  echo "airplane=no"
fi
pgrep -x hyprsunset >/dev/null && echo "night=on" || echo "night=off"
line=$(nmcli -t -e no -f IN-USE,SIGNAL,RATE dev wifi list 2>/dev/null | awk -F: '$1=="*"{print $2"|"$3; exit}')
echo "wsig=${line%%|*}"
echo "wrate=${line#*|}"
dev=$(ip route show default 2>/dev/null | awk '{print $5; exit}')
echo "rxb=$(cat /sys/class/net/$dev/statistics/rx_bytes 2>/dev/null)"
echo "txb=$(cat /sys/class/net/$dev/statistics/tx_bytes 2>/dev/null)"
echo "dnd=$(swaync-client -D 2>/dev/null)"
