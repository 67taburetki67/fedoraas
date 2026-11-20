#!/usr/bin/env bash
nmcli dev wifi rescan >/dev/null 2>&1
# сохранённые сети: имя профиля NetworkManager не равно SSID, поэтому берём настоящий SSID из каждого профиля
# формат строки: uuid<TAB>ssid<TAB>имя профиля
echo "##saved"
nmcli -t -e no -f UUID,TYPE,NAME connection show 2>/dev/null | while IFS= read -r line; do
  uuid=${line%%:*}; rest=${line#*:}
  [ "${rest%%:*}" = "802-11-wireless" ] || continue
  pname=${rest#*:}
  ssid=$(nmcli -g 802-11-wireless.ssid connection show uuid "$uuid" 2>/dev/null)
  [ -n "$ssid" ] || ssid=$pname
  printf '%s\t%s\t%s\n' "$uuid" "$ssid" "$pname"
done
echo "##nets"
nmcli -t -e no -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list
