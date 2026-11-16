#!/usr/bin/env bash
# Установщик Quickshell-райса для Fedora + Hyprland. Справка: ./install.sh --help
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/dotfiles"
TS=$(date +%Y%m%d-%H%M%S)
YES=0; PKGS=1; LOCK=0; DRY=0; LAYOUT=""

usage() { cat <<'U'
Использование: ./install.sh [параметры]
  --yes, -y       не задавать вопросов (раскладка us,ru)
  --no-packages   не ставить пакеты, только скопировать конфиги
  --with-lock     поставить экран блокировки и автоблокировку (по умолчанию пропускается)
  --layout us,ru  раскладки клавиатуры
  --dry-run       показать план и выйти
U
}
while [ $# -gt 0 ]; do
  case "$1" in
    --yes|-y) YES=1 ;;
    --no-packages) PKGS=0 ;;
    --with-lock) LOCK=1 ;;
    --layout) LAYOUT="${2:-}"; shift ;;
    --dry-run) DRY=1 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "неизвестный параметр: $1"; usage; exit 1 ;;
  esac
  shift
done

say()  { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[33m!! %s\033[0m\n' "$*"; }
ask()  { [ "$YES" = 1 ] && return 0; read -r -p "$1 [y/N] " a; [ "$a" = y ] || [ "$a" = Y ]; }

CORE="hyprland quickshell waybar SwayNotificationCenter foot fuzzel swaybg grim slurp wl-clipboard playerctl cava brightnessctl NetworkManager-wifi bluez wireplumber pipewire-utils pulseaudio-utils power-profiles-daemon socat ImageMagick polkit libnotify xdg-utils xdg-desktop-portal-hyprland tar curl jetbrains-mono-fonts bibata-cursor-themes adw-gtk3-theme qt6ct dconf gsettings-desktop-schemas firefox"
APPS="btop fastfetch mousepad Thunar loupe evince mpv file-roller"
LOCKP="hyprlock hypridle"

if [ "$(id -u)" = 0 ]; then echo "Запускай от обычного пользователя, не от root."; exit 1; fi
. /etc/os-release
if [ "${ID:-}" != fedora ]; then echo "Нужна Fedora (у тебя ${ID:-неизвестно}). Другие дистрибутивы пока не поддерживаются."; exit 1; fi
[ "${VERSION_ID:-0}" -ge 43 ] 2>/dev/null || warn "Проверено на Fedora 44, у тебя ${VERSION_ID:-?}"
VM=0; systemd-detect-virt -q 2>/dev/null && VM=1
[ -d "$SRC" ] || { echo "Не найдена папка dotfiles рядом со скриптом."; exit 1; }

if [ "$DRY" = 1 ]; then
  echo "План: проверка Fedora; пакеты: $([ $PKGS = 1 ] && echo да || echo нет); резервная копия; копирование конфигов; настройка Hyprland; темы и обои; программы по умолчанию; экран блокировки: $([ $LOCK = 1 ] && echo да || echo нет); виртуальная машина: $([ $VM = 1 ] && echo да || echo нет)"
  exit 0
fi

backup() {
  say "Резервная копия текущих настроек: ~/.rice-backup-$TS.tar.gz"
  local list=() d
  for d in .config/hypr .config/quickshell .config/waybar .config/swaync .config/fuzzel .config/foot .config/kitty .config/themes .config/gtk-3.0 .config/gtk-4.0 .config/qt6ct .config/btop .config/fastfetch .config/starship.toml .config/mimeapps.list .local/bin .bashrc; do
    [ -e "$HOME/$d" ] && list+=("$d")
  done
  [ ${#list[@]} -gt 0 ] && tar czf "$HOME/.rice-backup-$TS.tar.gz" -C "$HOME" "${list[@]}"
  return 0
}

packages() {
  say "Пакеты (это может занять несколько минут)"
  sudo dnf install -y --skip-unavailable dnf-plugins-core dnf5-plugins >/dev/null 2>&1
  if ! rpm -q hyprland >/dev/null 2>&1 && ! dnf info hyprland >/dev/null 2>&1; then
    if ask "Hyprland нет в официальных репозиториях Fedora. Подключить сторонний COPR ashbuk/Hyprland-Fedora?"; then
      sudo dnf copr enable -y ashbuk/Hyprland-Fedora || warn "COPR не подключился"
    fi
  fi
  local want="$CORE $APPS" miss=() p
  [ "$LOCK" = 1 ] && want="$want $LOCKP"
  sudo dnf install -y --skip-unavailable $want
  for p in $want; do rpm -q "$p" >/dev/null 2>&1 || miss+=("$p"); done
  [ ${#miss[@]} -gt 0 ] && warn "Не установились: ${miss[*]} (этих функций не будет, остальное работает)"
  fc-cache -f >/dev/null 2>&1
  return 0
}

deploy() {
  say "Копирую конфиги и скрипты"
  mkdir -p "$HOME/.config" "$HOME/.local/bin"
  cp -a "$SRC/config/." "$HOME/.config/"
  cp -a "$SRC/local/bin/." "$HOME/.local/bin/"
  chmod +x "$HOME"/.local/bin/* "$HOME"/.config/quickshell/scripts/*.sh "$HOME"/.config/waybar/*.sh 2>/dev/null
  mkdir -p "$HOME/Pictures/Screenshots" "$HOME/.local/share/quickshell-notes/files"
  [ -f "$HOME/.config/btop/btop.conf" ] || { mkdir -p "$HOME/.config/btop/themes"; echo 'color_theme = "mono"' > "$HOME/.config/btop/btop.conf"; }
}

hypr_setup() {
  say "Настраиваю Hyprland"
  local H="$HOME/.config/hypr" F="$HOME/.config/hypr/hyprland.lua" L="$LAYOUT"
  if [ ! -f "$F" ]; then
    if [ -f /usr/share/hypr/hyprland.lua ]; then cp /usr/share/hypr/hyprland.lua "$F"
    else warn "Нет $F: запусти Hyprland один раз и повтори установку"; return; fi
  fi
  [ -f "$F.orig-rice" ] || cp "$F" "$F.orig-rice"
  grep -q 'require("monochrome")' "$F" || echo 'require("monochrome")' >> "$F"
  grep -q 'pcall(require, "theme")' "$F" || echo 'pcall(require, "theme")' >> "$F"
  grep -q 'pcall(require, "layout")' "$F" || echo 'pcall(require, "layout")' >> "$F"
  sed -i 's|^local terminal[[:space:]]*=.*|local terminal    = "foot"|; s|^local fileManager[[:space:]]*=.*|local fileManager = "thunar"|; s|^local menu[[:space:]]*=.*|local menu        = "quickshell ipc call launcher toggle"|' "$F"
  if [ -z "$L" ]; then
    if [ "$YES" = 1 ]; then L="us,ru"; else read -r -p "Раскладки клавиатуры через запятую [us,ru]: " L; L="${L:-us,ru}"; fi
  fi
  {
    echo "-- создано install.sh"
    echo "hl.config({ input = { kb_layout = \"$L\", kb_options = \"grp:alt_shift_toggle\" } })"
    [ "$VM" = 1 ] && echo 'hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", position = "0x0", scale = 1 })'
  } > "$H/layout.lua"
}

shell_setup() {
  touch "$HOME/.bashrc"
  grep -q 'rice-begin' "$HOME/.bashrc" || cat >> "$HOME/.bashrc" <<'B'

# rice-begin
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
[ -f "$HOME/.config/themes/shell.sh" ] && source "$HOME/.config/themes/shell.sh"
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
# rice-end
B
}

starship_setup() {
  command -v starship >/dev/null 2>&1 && return 0
  [ "$PKGS" = 1 ] || return 0
  sudo dnf install -y starship >/dev/null 2>&1 && return 0
  if ask "Поставить starship (красивая строка терминала) с официального сайта в ~/.local/bin?"; then
    curl -sS https://starship.rs/install.sh | sh -s -- -b "$HOME/.local/bin" -y || warn "starship не поставился"
  fi
  return 0
}

gen_wallpapers() {
  local IM="" f n d BG S2 has
  if command -v magick >/dev/null 2>&1; then IM=magick; elif command -v convert >/dev/null 2>&1; then IM=convert; fi
  if [ -z "$IM" ]; then warn "Нет ImageMagick: обои не созданы, положи свои в ~/.config/themes/wallpapers/<тема>/"; return; fi
  for f in "$HOME"/.config/themes/themes/*.env; do
    n=$(basename "$f" .env); d="$HOME/.config/themes/wallpapers/$n"; mkdir -p "$d"
    has=$(find "$d" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) | head -1)
    [ -n "$has" ] && continue
    BG=$(grep -m1 '^BG=' "$f" | cut -d= -f2); S2=$(grep -m1 '^SURFACE2=' "$f" | cut -d= -f2)
    $IM -size 1920x1080 "radial-gradient:#${S2}-#${BG}" "$d/default.png" 2>/dev/null
  done
}

themes_setup() {
  say "Создаю темы и обои"
  local t
  for t in "red 355 60" "orange 26 75" "yellow 48 70" "lime 85 55" "mint 150 50" "teal 174 55" "cyan 190 60" "indigo 235 55" "purple 270 50" "magenta 305 55" "pink 330 60" "brown 24 38"; do
    set -- $t; "$HOME/.local/bin/theme-gen" "$@" >/dev/null
  done
  "$HOME/.local/bin/theme-gen" cat 340 55 paws >/dev/null
  gen_wallpapers
  "$HOME/.local/bin/theme" gray >/dev/null 2>&1
}

setdef() {
  local ids="$1" id c m; shift
  for c in $ids; do [ -f "/usr/share/applications/$c" ] && { id="$c"; break; }; done
  [ -z "${id:-}" ] && return 0
  for m in "$@"; do xdg-mime default "$id" "$m" 2>/dev/null; done
}
mime_setup() {
  say "Назначаю программы по умолчанию (блокнот, просмотр картинок, PDF, видео)"
  command -v xdg-mime >/dev/null 2>&1 || return 0
  setdef "org.xfce.mousepad.desktop mousepad.desktop" text/plain text/markdown text/x-log text/x-python text/x-csrc text/x-chdr text/x-c++src text/x-shellscript application/x-shellscript application/json application/xml application/x-yaml application/toml application/x-desktop text/csv text/x-makefile text/css text/x-diff application/octet-stream
  setdef "org.gnome.Loupe.desktop" image/png image/jpeg image/gif image/webp image/bmp image/svg+xml
  setdef "org.gnome.Evince.desktop" application/pdf
  setdef "mpv.desktop io.mpv.Mpv.desktop" video/mp4 video/x-matroska video/webm audio/mpeg audio/flac audio/ogg
  setdef "thunar.desktop" inode/directory
  setdef "org.gnome.FileRoller.desktop" application/zip application/x-tar application/gzip application/x-7z-compressed
}

gtk_setup() {
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null
  gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 11' 2>/dev/null
  return 0
}

lock_setup() {
  if [ "$LOCK" = 1 ]; then
    [ -f "$HOME/.config/hypr/hypridle.real.conf" ] && cp "$HOME/.config/hypr/hypridle.real.conf" "$HOME/.config/hypr/hypridle.conf"
    say "Экран блокировки включён (hyprlock и hypridle)"
  else
    sed -i '/hyprlock/d' "$HOME/.config/quickshell/QuickSettings.qml" "$HOME/.config/quickshell/Launcher.qml" 2>/dev/null
    say "Экран блокировки пропущен: кнопки «заблокировать» убраны, автоблокировки нет"
  fi
}

backup
[ "$PKGS" = 1 ] && packages
deploy
hypr_setup
shell_setup
starship_setup
themes_setup
mime_setup
gtk_setup
lock_setup

say "Готово."
cat <<'DONE'

Что дальше:
  1. Выйди из текущей сессии или перейди в TTY (Ctrl+Alt+F3) и запусти:  start-hyprland
     (в Fedora Workstation Hyprland может появиться в списке сессий на экране входа)
  2. SUPER+/ — шпаргалка клавиш, SUPER+W — виджеты, SUPER+D — лаунчер, SUPER+Q — терминал
  3. Диагностика:  rice-check     Перезапуск:  rice restart quickshell     Тема:  theme purple
  4. Обои для каждой темы:  ~/.config/themes/wallpapers/<тема>/
Если что-то пошло не так, резервная копия: ~/.rice-backup-*.tar.gz (откат: ./uninstall.sh)
DONE
