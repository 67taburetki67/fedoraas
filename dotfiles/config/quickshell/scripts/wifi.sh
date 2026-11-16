#!/usr/bin/env bash
nmcli dev wifi rescan >/dev/null 2>&1
echo "##saved"
nmcli -t -e no -f NAME,TYPE connection show | awk -F: '$NF=="802-11-wireless"{sub(/:802-11-wireless$/,""); print}'
echo "##nets"
nmcli -t -e no -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list
