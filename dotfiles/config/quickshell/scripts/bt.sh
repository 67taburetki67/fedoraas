#!/usr/bin/env bash
bluetoothctl devices 2>/dev/null | while read -r _ mac name; do
  c=$(bluetoothctl info "$mac" 2>/dev/null | awk '/Connected:/{print $2}')
  echo "$mac|${c:-no}|$name"
done
