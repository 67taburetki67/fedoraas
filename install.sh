#!/usr/bin/env bash
# Установщик Quickshell-райса для Fedora + Hyprland. Справка: ./install.sh --help
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
SRC="$ROOT/dotfiles"
TS=$(date +%Y%m%d-%H%M%S)
STATE_DIR="$HOME/.local/share/fedoraas"
MANIFEST="$STATE_DIR/manifest"
YES=0; PKGS=1; LOCK=0; DRY=0; LAYOUT=""

usage() { cat <<'U'
Использование: ./install.sh [параметры]
  --yes, -y       не задавать вопросов (раскладка us,ru)
  --no-packages   не ставить пакеты, только скопировать конфиги
  --with-lock     поставить hyprlock для ручной блокировки экрана (автоблокировки нет никогда)
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

WARNS=(); FAILS=()
say()       { printf '\033[1m==> %s\033[0m\n' "$*"; }
warn()      { printf '\033[33m!! %s\033[0m\n' "$*"; WARNS+=("$*"); }
fail()      { printf '\033[31mxx %s\033[0m\n' "$*"; FAILS+=("$*"); }
ask()       { [ "$YES" = 1 ] && return 0; read -r -p "$1 [y/N] " a; [ "$a" = y ] || [ "$a" = Y ]; }

# без этих пакетов сессия не заработает; всё остальное лишь отключает отдельные функции
CRITICAL="hyprland quickshell waybar SwayNotificationCenter foot swaybg wl-clipboard xdg-desktop-portal-hyprland"
OPTIONAL="fuzzel grim slurp playerctl cava brightnessctl NetworkManager-wifi bluez wireplumber pipewire-utils pulseaudio-utils power-profiles-daemon socat ImageMagick polkit libnotify xdg-utils tar curl jetbrains-mono-fonts bibata-cursor-themes adw-gtk3-theme qt6ct dconf gsettings-desktop-schemas firefox cliphist satty hyprsunset"
APPS="btop fastfetch mousepad Thunar loupe evince mpv file-roller"
LOCKP="hyprlock"

feature() {
  case "$1" in
    cliphist) echo "история буфера обмена (SUPER+SHIFT+V)" ;;
    satty) echo "разметка скриншотов (без неё сохраняется обычный снимок)" ;;
    hyprsunset) echo "ночной режим" ;;
    socat) echo "номера рабочих столов в панели" ;;
    grim|slurp) echo "скриншоты" ;;
    playerctl|cava) echo "плеер и визуализатор" ;;
    brightnessctl) echo "яркость" ;;
    ImageMagick) echo "обои по умолчанию и скругление стикеров" ;;
    NetworkManager-wifi|bluez) echo "панели Wi-Fi и Bluetooth" ;;
    pipewire-utils|pulseaudio-utils|wireplumber) echo "громкость и звук" ;;
    jetbrains-mono-fonts) echo "шрифт интерфейса" ;;
    fuzzel) echo "выбор из истории буфера" ;;
    *) echo "часть возможностей" ;;
  esac
}

if [ "$(id -u)" = 0 ]; then echo "Запускай от обычного пользователя, не от root."; exit 1; fi
. /etc/os-release
if [ "${ID:-}" != fedora ]; then echo "Нужна Fedora (у тебя ${ID:-неизвестно}). Другие дистрибутивы пока не поддерживаются."; exit 1; fi
case "${VERSION_ID:-0}" in
  44|45) ;;
  *) warn "Проверено на Fedora 44 и 45, у тебя ${VERSION_ID:-?}: возможны сюрпризы" ;;
esac
VM=0; systemd-detect-virt -q 2>/dev/null && VM=1
[ -d "$SRC" ] || { echo "Не найдена папка dotfiles рядом со скриптом."; exit 1; }

if [ "$DRY" = 1 ]; then
  echo "План: проверка Fedora; пакеты: $([ "$PKGS" = 1 ] && echo да || echo нет); резервная копия; копирование конфигов; настройка Hyprland; темы и обои; программы по умолчанию; экран блокировки: $([ "$LOCK" = 1 ] && echo да || echo нет); виртуальная машина: $([ "$VM" = 1 ] && echo да || echo нет)"
  exit 0
fi

backup() {
  # первая установка: ~/.rice-backup-* (чистое состояние, к нему откатывает uninstall.sh);
  # повторная: ~/.rice-update-* (в ней уже сам райс, поэтому для отката она не годится)
  local kind=backup out list=() d
  if [ -f "$MANIFEST" ] || [ -f "$HOME/.config/quickshell/shell.qml" ]; then kind=update; fi
  out="$HOME/.rice-$kind-$TS.tar.gz"
  say "Резервная копия текущих настроек: $out"
  for d in .config/hypr .config/quickshell .config/waybar .config/swaync .config/fuzzel .config/foot .config/kitty .config/themes .config/gtk-3.0 .config/gtk-4.0 .config/qt6ct .config/btop .config/fastfetch .config/starship.toml .config/mimeapps.list .local/bin .bashrc; do
    [ -e "$HOME/$d" ] && list+=("$d")
  done
  [ ${#list[@]} -gt 0 ] || return 0
  # без проверенной копии ничего не перезаписываем
  if ! tar czf "$out" -C "$HOME" "${list[@]}" || ! tar tzf "$out" >/dev/null 2>&1; then
    rm -f "$out"
    return 1
  fi
  return 0
}

have_pkg() { rpm -q "$1" >/dev/null 2>&1; }

packages() {
  say "Пакеты (это может занять несколько минут)"
  sudo dnf install -y --skip-unavailable dnf-plugins-core dnf5-plugins >/dev/null 2>&1
  if ! have_pkg hyprland && ! dnf info hyprland >/dev/null 2>&1; then
    if ask "Hyprland нет в официальных репозиториях Fedora. Подключить сторонний COPR ashbuk/Hyprland-Fedora?"; then
      sudo dnf copr enable -y ashbuk/Hyprland-Fedora || warn "COPR не подключился"
    fi
  fi
  local want="$CRITICAL $OPTIONAL $APPS" miss_c=() miss_o=() p
  [ "$LOCK" = 1 ] && want="$want $LOCKP"
  # shellcheck disable=SC2086
  sudo dnf install -y --skip-unavailable $want
  for p in $want; do
    have_pkg "$p" && continue
    case " $CRITICAL " in *" $p "*) miss_c+=("$p") ;; *) miss_o+=("$p") ;; esac
  done
  for p in "${miss_o[@]}"; do warn "не установился $p: не будет функции «$(feature "$p")»"; done
  [ ${#miss_c[@]} -gt 0 ] && fail "не установились обязательные пакеты: ${miss_c[*]} (сессия работать не будет, пока их нет)"
  fc-cache -f >/dev/null 2>&1
  return 0
}

src_files() {
  (cd "$SRC/config" && find . -type f -printf '.config/%P\n')
  (cd "$SRC/local/bin" && find . -type f -printf '.local/bin/%P\n')
}

deploy() {
  say "Копирую конфиги и скрипты"
  mkdir -p "$HOME/.config" "$HOME/.local/bin" "$STATE_DIR"
  local new rel
  new=$(mktemp) || return 1
  src_files | sort > "$new"
  # файлы, которые прошлая установка ставила, а в этой версии их уже нет, удаляем
  if [ -f "$MANIFEST" ]; then
    comm -23 <(sort "$MANIFEST") "$new" | while IFS= read -r rel; do
      case "$rel" in *..*) continue ;; .config/*|.local/bin/*) ;; *) continue ;; esac
      [ -f "$HOME/$rel" ] && rm -f -- "$HOME/$rel" && echo "  удалён устаревший файл: $rel"
    done
  fi
  if ! cp -a "$SRC/config/." "$HOME/.config/" || ! cp -a "$SRC/local/bin/." "$HOME/.local/bin/"; then
    rm -f "$new"; return 1
  fi
  chmod +x "$HOME"/.local/bin/* "$HOME"/.config/quickshell/scripts/*.sh "$HOME"/.config/waybar/*.sh 2>/dev/null
  cp -f "$new" "$MANIFEST"; rm -f "$new"
  # хвосты прошлых версий: шейдер и автоблокировка удалены из райса совсем
  rm -f "$HOME/.config/hypr/shaders/grain.frag" "$HOME/.config/themes/shader" "$HOME/.config/hypr/hypridle.conf"
  rmdir "$HOME/.config/hypr/shaders" 2>/dev/null
  pkill -x hypridle 2>/dev/null
  mkdir -p "$HOME/Pictures/Screenshots" "$HOME/.local/share/quickshell-notes/files"
  [ -f "$HOME/.config/btop/btop.conf" ] || { mkdir -p "$HOME/.config/btop/themes"; echo 'color_theme = "mono"' > "$HOME/.config/btop/btop.conf"; }
  return 0
}

valid_layout() { [[ "$1" =~ ^[a-z0-9_]+(,[a-z0-9_]+)*$ ]]; }

hypr_setup() {
  say "Настраиваю Hyprland"
  local H="$HOME/.config/hypr" F="$HOME/.config/hypr/hyprland.lua" L="$LAYOUT" tmp
  if [ ! -f "$F" ]; then
    if [ -f /usr/share/hypr/hyprland.lua ]; then cp /usr/share/hypr/hyprland.lua "$F"
    else fail "нет $F: запусти Hyprland один раз и повтори установку"; return 1; fi
  fi
  [ -f "$F.orig-rice" ] || cp "$F" "$F.orig-rice"
  grep -q 'require("monochrome")' "$F" || echo 'require("monochrome")' >> "$F"
  grep -q 'pcall(require, "theme")' "$F" || echo 'pcall(require, "theme")' >> "$F"
  grep -q 'pcall(require, "layout")' "$F" || echo 'pcall(require, "layout")' >> "$F"
  sed -i 's|^local terminal[[:space:]]*=.*|local terminal    = "foot"|; s|^local fileManager[[:space:]]*=.*|local fileManager = "thunar"|; s|^local menu[[:space:]]*=.*|local menu        = "quickshell ipc call launcher toggle"|' "$F"
  if [ -z "$L" ]; then
    if [ "$YES" = 1 ]; then L="us,ru"; else read -r -p "Раскладки клавиатуры через запятую [us,ru]: " L; L="${L:-us,ru}"; fi
  fi
  if ! valid_layout "$L"; then
    warn "раскладка «$L» не похожа на список XKB-раскладок (пример: us,ru), использую us,ru"
    L="us,ru"
  fi
  tmp=$(mktemp "$H/.layout.XXXXXX") || return 1
  {
    echo "-- создано install.sh"
    echo "hl.config({ input = { kb_layout = \"$L\", kb_options = \"grp:alt_shift_toggle\" } })"
    if [ "$VM" = 1 ]; then
      echo 'hl.monitor({ output = "Virtual-1", mode = "1920x1080@60", position = "0x0", scale = 1 })'
      echo '-- виртуальная машина: kitty и другие GL-программы падают с ошибкой EGL, поэтому они идут на программном рендере.'
      echo '-- Если все программы у тебя работают и без этого, строку ниже можно удалить.'
      echo 'hl.env("LIBGL_ALWAYS_SOFTWARE", "1")'
    fi
  } > "$tmp" && mv -f "$tmp" "$H/layout.lua"
}

shell_setup() {
  touch "$HOME/.bashrc"
  # блок райса пересоздаётся при каждой установке, чтобы новые версии обновляли его
  sed -i '/^# rice-begin$/,/^# rice-end$/d' "$HOME/.bashrc"
  cat >> "$HOME/.bashrc" <<'B'

# rice-begin
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
[ -f "$HOME/.config/themes/shell.sh" ] && source "$HOME/.config/themes/shell.sh"
command -v starship >/dev/null 2>&1 && eval "$(starship init bash)"
# Fedora 45: на консоли работает kmscon, и Hyprland стартует только через kmscon-launch-gui
if command -v kmscon-launch-gui >/dev/null 2>&1; then
  alias hypr='kmscon-launch-gui start-hyprland'
else
  alias hypr='start-hyprland'
fi
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
  if [ -z "$IM" ]; then warn "нет ImageMagick: обои не созданы, положи свои в ~/.config/themes/wallpapers/<тема>/"; return; fi
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
  local t a
  for t in "red 355 60" "orange 26 75" "yellow 48 70" "lime 85 55" "mint 150 50" "teal 174 55" "cyan 190 60" "indigo 235 55" "purple 270 50" "magenta 305 55" "pink 330 60" "brown 24 38"; do
    read -r -a a <<< "$t"
    "$HOME/.local/bin/theme-gen" "${a[@]}" >/dev/null || warn "тема ${a[0]} не создалась"
  done
  "$HOME/.local/bin/theme-gen" cat 340 55 paws >/dev/null || warn "тема cat не создалась"
  gen_wallpapers
  # при установке обои и перезагрузку сессии не трогаем (THEME_NO_RELOAD), и ввода у команды нет
  if ! THEME_NO_RELOAD=1 timeout 60 "$HOME/.local/bin/theme" gray </dev/null >/dev/null 2>&1; then
    fail "не удалось применить тему gray (запусти ~/.local/bin/theme gray и посмотри ошибку)"
  fi
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
  setdef "org.xfce.mousepad.desktop mousepad.desktop" text/plain text/markdown text/x-log text/x-python text/x-csrc text/x-chdr text/x-c++src text/x-shellscript application/x-shellscript application/json application/xml application/x-yaml application/toml application/x-desktop text/csv text/x-makefile text/css text/x-diff
  setdef "org.gnome.Loupe.desktop" image/png image/jpeg image/gif image/webp image/bmp image/svg+xml
  setdef "org.gnome.Evince.desktop" application/pdf
  setdef "mpv.desktop io.mpv.Mpv.desktop" video/mp4 video/x-matroska video/webm audio/mpeg audio/flac audio/ogg
  setdef "thunar.desktop" inode/directory
  setdef "org.gnome.FileRoller.desktop" application/zip application/x-tar application/gzip application/x-7z-compressed
}

gtk_setup() {
  command -v gsettings >/dev/null 2>&1 || return 0
  local f="$STATE_DIR/gsettings-prev" k
  # прежние значения запоминаем один раз, чтобы uninstall.sh вернул их обратно
  if [ ! -f "$f" ]; then
    : > "$f.tmp"
    for k in color-scheme gtk-theme cursor-theme font-name; do
      printf '%s\t%s\n' "$k" "$(gsettings get org.gnome.desktop.interface "$k" 2>/dev/null)" >> "$f.tmp"
    done
    mv -f "$f.tmp" "$f"
  fi
  gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null
  gsettings set org.gnome.desktop.interface gtk-theme 'adw-gtk3-dark' 2>/dev/null
  gsettings set org.gnome.desktop.interface cursor-theme 'Bibata-Modern-Classic' 2>/dev/null
  gsettings set org.gnome.desktop.interface font-name 'JetBrains Mono 11' 2>/dev/null
  return 0
}

lock_setup() {
  if [ "$LOCK" = 1 ]; then
    have_pkg hyprlock || warn "не установлен hyprlock: кнопка «заблокировать» не заработает"
    say "hyprlock для ручной блокировки готов (автоблокировки нет)"
  else
    say "Экран блокировки пропущен (кнопка «заблокировать» сама подскажет, как его поставить)"
  fi
}

backup || { echo "Не удалось создать резервную копию, ничего не изменено. Проверь место на диске и права."; exit 1; }
[ "$PKGS" = 1 ] && packages
deploy || { echo "Не удалось скопировать конфиги."; exit 1; }
hypr_setup
shell_setup
starship_setup
themes_setup
mime_setup
gtk_setup
lock_setup

echo
if [ ${#FAILS[@]} -gt 0 ]; then
  say "Установка завершена с ошибками:"
  printf '  - %s\n' "${FAILS[@]}"
fi
if [ ${#WARNS[@]} -gt 0 ]; then
  say "Предупреждения (остальное работает):"
  printf '  - %s\n' "${WARNS[@]}"
fi
[ ${#FAILS[@]} -eq 0 ] && say "Готово."

if command -v kmscon-launch-gui >/dev/null 2>&1; then
  START="kmscon-launch-gui start-hyprland"
else
  START="start-hyprland"
fi
cat <<DONE

Что дальше:
  1. Выйди из текущей сессии или перейди в TTY (Ctrl+Alt+F3), открой новый терминал (чтобы подхватился ~/.bashrc) и запусти:  hypr
     (это то же, что: $START)
  2. SUPER+/ — шпаргалка клавиш, SUPER+W — виджеты, SUPER+D — лаунчер, SUPER+Q — терминал
  3. Диагностика:  rice-check     Перезапуск:  rice restart quickshell     Тема:  theme purple
  4. Обои для каждой темы:  ~/.config/themes/wallpapers/<тема>/
Резервные копии: ~/.rice-backup-*.tar.gz (первая установка) и ~/.rice-update-*.tar.gz (повторные). Откат: ./uninstall.sh
DONE
[ ${#FAILS[@]} -eq 0 ] || exit 2
exit 0
