#!/usr/bin/env bash
dir="$HOME/Pictures/Screenshots"; mkdir -p "$dir"
f="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
case "$1" in
  region) geo=$(slurp) || exit 0; grim -g "$geo" "$f" ;;
  full)   grim "$f" ;;
  edit)
    geo=$(slurp) || exit 0
    if command -v satty >/dev/null; then
      grim -g "$geo" - | satty --filename - --output-filename "$f" --copy-command wl-copy
      exit 0
    else
      # редактора нет: сохраняем обычный снимок и говорим об этом, а не молчим
      grim -g "$geo" "$f"
      command -v notify-send >/dev/null && notify-send "Скриншот без разметки" "satty не установлен (sudo dnf install -y satty), сохранён обычный снимок"
    fi ;;
esac
if [ -f "$f" ]; then
  wl-copy < "$f"
  command -v notify-send >/dev/null && notify-send "Скриншот" "$f"
fi
