#!/usr/bin/env bash
# Откат райса. Удаляет только то, что поставил install.sh (список в манифесте), убирает свои строки из
# hyprland.lua и .bashrc, возвращает прежние настройки GNOME и файлы из резервной копии.
# Твои обои, заметки и собственные темы не трогает.
# Использование: ./uninstall.sh [--yes] [--dry-run] [архив.tar.gz]
set -u
STATE_DIR="$HOME/.local/share/fedoraas"
MANIFEST="$STATE_DIR/manifest"
YES=0; DRY=0; B=""
for a in "$@"; do
  case "$a" in
    --yes|-y) YES=1 ;;
    --dry-run) DRY=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) B="$a" ;;
  esac
done

say() { printf '\033[1m==> %s\033[0m\n' "$*"; }
act() { if [ "$DRY" = 1 ]; then echo "  [dry-run] $*"; else "$@"; fi; }
safe_rel() { case "$1" in *..*) return 1 ;; .config/*|.local/bin/*) return 0 ;; *) return 1 ;; esac; }

# 1. какую копию использовать
if [ -z "$B" ]; then B=$(ls -t "$HOME"/.rice-backup-*.tar.gz 2>/dev/null | head -1); fi
if [ -n "$B" ]; then
  if ! tar tzf "$B" >/dev/null 2>&1; then echo "Архив $B повреждён или не читается. Укажи другой: ./uninstall.sh <архив>"; exit 1; fi
  echo "Резервная копия: $B"
  echo "Все копии:"; ls -t "$HOME"/.rice-backup-*.tar.gz "$HOME"/.rice-update-*.tar.gz 2>/dev/null | sed 's/^/  /'
  echo "(по умолчанию берётся копия первой установки, ~/.rice-backup-*: в копиях ~/.rice-update-* уже лежит сам райс)"
else
  echo "Резервных копий ~/.rice-backup-*.tar.gz нет: удалю файлы райса, а прежние настройки вернуть будет нечем."
fi
if [ ! -f "$MANIFEST" ]; then
  echo "Нет списка установленных файлов ($MANIFEST): райс ставился старой версией install.sh."
  echo "Переустанови ./install.sh (он создаст список), затем запусти откат ещё раз."
  exit 1
fi
echo
echo "Будет сделано:"
echo "  - остановлены quickshell, waybar, swaync;"
echo "  - удалены файлы райса из ~/.config и ~/.local/bin (по списку установки) и созданные темами конфиги;"
echo "  - убраны строки райса из ~/.config/hypr/hyprland.lua и ~/.bashrc;"
echo "  - возвращены настройки темы GNOME и файлы из резервной копии (то, чего сейчас нет на месте)."
echo "Обои, заметки (~/.local/share/quickshell-notes) и твои собственные темы останутся."
if [ "$DRY" = 0 ] && [ "$YES" = 0 ]; then
  read -r -p "Продолжить? [y/N] " a; [ "$a" = y ] || [ "$a" = Y ] || exit 0
fi

# 2. остановка
say "Останавливаю службы райса"
if [ -x "$HOME/.local/bin/rice" ]; then act "$HOME/.local/bin/rice" stop; else act pkill -x quickshell; act pkill -x waybar; act pkill -x swaync; fi
act pkill -x swaybg

# 3. файлы по манифесту
say "Удаляю файлы райса"
while IFS= read -r rel; do
  safe_rel "$rel" || continue
  [ -e "$HOME/$rel" ] && act rm -f -- "$HOME/$rel"
done < "$MANIFEST"
# то, что создают команды theme, theme-gen и install.sh, но чего нет в репозитории
for rel in .config/waybar/style.css .config/swaync/style.css .config/fuzzel/fuzzel.ini .config/foot/foot.ini .config/kitty/mono.conf \
           .config/hypr/hyprlock.conf .config/hypr/theme.lua .config/hypr/layout.lua .config/hypr/hypridle.conf .config/hypr/shaders/grain.frag \
           .config/gtk-3.0/gtk.css .config/gtk-4.0/gtk.css .config/qt6ct/colors/mono.conf .config/starship.toml .config/btop/themes/mono.theme \
           .config/themes/shell.sh .config/themes/colors.json .config/themes/current .config/themes/current-wall .config/themes/shader .config/themes/.lock; do
  [ -e "$HOME/$rel" ] && act rm -f -- "$HOME/$rel"
done
for t in red orange yellow lime mint teal cyan indigo purple magenta pink brown cat; do
  act rm -f -- "$HOME/.config/themes/themes/$t.env"
done
# обои default.png создаёт install.sh для тем без картинок; свои обои (с другими именами) не трогаем
for f in "$HOME"/.config/themes/wallpapers/*/default.png; do [ -f "$f" ] && act rm -f -- "$f"; done
# btop.conf install.sh создаёт только если его не было; если ты его не менял, убираем
if [ -f "$HOME/.config/btop/btop.conf" ] && [ "$(cat "$HOME/.config/btop/btop.conf")" = 'color_theme = "mono"' ]; then
  act rm -f -- "$HOME/.config/btop/btop.conf"
fi
find "$HOME/.config" "$HOME/.local/bin" -name '*.theme-bak' -type f -print0 2>/dev/null | while IFS= read -r -d '' f; do act rm -f -- "$f"; done
# пустые каталоги убираем, непустые (с твоими обоями и темами) остаются
if [ "$DRY" = 0 ]; then
  find "$HOME/.config/themes" "$HOME/.config/quickshell" "$HOME/.config/hypr/shaders" "$HOME/.config/btop" -depth -type d -empty -delete 2>/dev/null
fi

# 4. hyprland.lua
F="$HOME/.config/hypr/hyprland.lua"
if [ -f "$F" ]; then
  say "Чищу $F"
  norm() { sed -E 's/^local (terminal|fileManager|menu)[[:space:]]*=.*/local \1 = X/'; }
  rice_lines() { grep -vxF -e 'require("monochrome")' -e 'pcall(require, "theme")' -e 'pcall(require, "layout")' "$1"; }
  if [ -f "$F.orig-rice" ] && [ "$(rice_lines "$F" | norm)" = "$(norm < "$F.orig-rice")" ]; then
    # после установки файл менялся только строками райса: возвращаем оригинал целиком
    act cp -f -- "$F.orig-rice" "$F"
    act rm -f -- "$F.orig-rice"
    echo "  hyprland.lua возвращён к исходному виду"
  else
    if [ "$DRY" = 0 ]; then
      tmp=$(mktemp) && rice_lines "$F" > "$tmp" && cat "$tmp" > "$F"; rm -f "$tmp"
    fi
    echo "  убраны строки require(\"monochrome\"), theme и layout; файл правился и после установки, поэтому остальное не тронуто"
    echo "  (переменные terminal, fileManager, menu установка заменила на foot, thunar и лаунчер; оригинал: $F.orig-rice)"
  fi
fi

# 5. .bashrc
if [ -f "$HOME/.bashrc" ] && grep -q '^# rice-begin$' "$HOME/.bashrc"; then
  say "Убираю блок райса из ~/.bashrc (остальное в файле не трогаю)"
  act sed -i '/^# rice-begin$/,/^# rice-end$/d' "$HOME/.bashrc"
fi

# 6. настройки GNOME
if [ -f "$STATE_DIR/gsettings-prev" ] && command -v gsettings >/dev/null 2>&1; then
  say "Возвращаю прежнюю тему GTK, курсор и шрифт"
  while IFS=$'\t' read -r k v; do
    [ -n "$k" ] || continue
    if [ -n "$v" ]; then act gsettings set org.gnome.desktop.interface "$k" "$v"; else act gsettings reset org.gnome.desktop.interface "$k"; fi
  done < "$STATE_DIR/gsettings-prev"
fi

# 7. резервная копия: возвращаем то, чего сейчас нет, и список программ по умолчанию
if [ -n "$B" ]; then
  say "Возвращаю файлы из резервной копии (существующие не перезаписываю)"
  act tar xzf "$B" -C "$HOME" --skip-old-files
  if tar tzf "$B" 2>/dev/null | grep -qx '.config/mimeapps.list'; then
    act tar xzf "$B" -C "$HOME" .config/mimeapps.list
    echo "  программы по умолчанию (mimeapps.list) возвращены из копии"
  fi
fi

# 8. служебные данные установки
act rm -f -- "$MANIFEST" "$STATE_DIR/gsettings-prev"
[ "$DRY" = 0 ] && rmdir "$STATE_DIR" 2>/dev/null

echo
say "Готово."
echo "Пакеты, которые ставил install.sh, не удалялись (sudo dnf remove ...), копии ~/.rice-backup-*.tar.gz остались."
echo "Открой новый терминал, чтобы пропал алиас hypr и строка starship."
