#!/usr/bin/env bash
p=()
[ -n "$1" ] && p=(-p "$1")
echo "players=$(playerctl -l 2>/dev/null | paste -sd, -)"
# разделитель \x1f: в названиях треков часто встречается « | »; статус берём тем же вызовом, что и метаданные
fmt=$'{{status}}\x1f{{artist}}\x1f{{title}}\x1f{{album}}\x1f{{mpris:artUrl}}\x1f{{mpris:length}}\x1f{{playerName}}'
IFS=$'\x1f' read -r st artist title album art len name < <(playerctl "${p[@]}" metadata --format "$fmt" 2>/dev/null)
if [ -z "$st" ]; then echo "status=none"; exit 0; fi
echo "status=$st"
echo "artist=$artist"
echo "title=$title"
echo "album=$album"
echo "art=$art"
echo "len=$len"
echo "name=$name"
echo "pos=$(playerctl "${p[@]}" position 2>/dev/null)"
echo "shuffle=$(playerctl "${p[@]}" shuffle 2>/dev/null)"
echo "loop=$(playerctl "${p[@]}" loop 2>/dev/null)"
