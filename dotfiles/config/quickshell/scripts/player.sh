#!/usr/bin/env bash
p=()
[ -n "$1" ] && p=(-p "$1")
st=$(playerctl "${p[@]}" status 2>/dev/null)
echo "players=$(playerctl -l 2>/dev/null | paste -sd, -)"
if [ -z "$st" ]; then echo "status=none"; exit 0; fi
fmt='{{artist}}|{{title}}|{{album}}|{{mpris:artUrl}}|{{mpris:length}}|{{playerName}}'
IFS='|' read -r artist title album art len name < <(playerctl "${p[@]}" metadata --format "$fmt" 2>/dev/null)
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
