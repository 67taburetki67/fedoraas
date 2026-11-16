#!/usr/bin/env bash
read -r a1 t1 < <(awk '/^cpu /{print $2+$3+$4+$7+$8, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
sleep 1
read -r a2 t2 < <(awk '/^cpu /{print $2+$3+$4+$7+$8, $2+$3+$4+$5+$6+$7+$8}' /proc/stat)
[ "$t2" -gt "$t1" ] || t2=$((t1 + 1))
cpu=$(( (a2 - a1) * 100 / (t2 - t1) ))
mem=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%d", (t-a)*100/t}' /proc/meminfo)
t=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
echo "$cpu $mem $(( ${t:-0} / 1000 ))"
