#!/usr/bin/env bash
# Откат: возвращает конфиги из последней резервной копии install.sh
b=$(ls -t "$HOME"/.rice-backup-*.tar.gz 2>/dev/null | head -1)
if [ -z "$b" ]; then echo "Резервная копия ~/.rice-backup-*.tar.gz не найдена."; exit 1; fi
echo "Будет восстановлено из: $b"
echo "Каталоги райса (quickshell, waybar, themes, ~/.local/bin/theme и др.) будут удалены и заменены копией."
read -r -p "Продолжить? [y/N] " a; [ "$a" = y ] || [ "$a" = Y ] || exit 0
pkill -x quickshell 2>/dev/null; pkill -x waybar 2>/dev/null; pkill -x swaync 2>/dev/null
rm -rf "$HOME"/.config/quickshell "$HOME"/.config/themes "$HOME"/.config/waybar "$HOME"/.config/swaync
rm -f "$HOME"/.local/bin/{theme,theme-gen,rice,rice-check,supervise,perf,shot.sh,clip.sh,spawnrate}
rm -f "$HOME"/.config/hypr/{monochrome.lua,theme.lua,layout.lua}
tar xzf "$b" -C "$HOME"
echo "Готово. Из ~/.config/hypr/hyprland.lua убери строки require(\"monochrome\"), pcall(require, \"theme\"), pcall(require, \"layout\"), если они остались (оригинал лежит рядом: hyprland.lua.orig-rice)."
