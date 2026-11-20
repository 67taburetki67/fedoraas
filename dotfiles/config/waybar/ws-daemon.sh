#!/usr/bin/env bash
RUN="${XDG_RUNTIME_DIR:-/tmp}"
STATE="$RUN/ws-active"
trap 'pkill -P $$ 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP
active() { hyprctl activeworkspace -j 2>/dev/null | grep -m1 '"id"' | tr -dc '0-9-'; }
publish() {
  local cur="$1" old=""
  [ -z "$cur" ] && return
  read -r old < "$STATE" 2>/dev/null
  if [ "$old" != "$cur" ]; then
    echo "$cur" > "$STATE"
    pkill -RTMIN+8 -x waybar 2>/dev/null
  fi
}
publish "$(active)"
SOCK="$RUN/hypr/${HYPRLAND_INSTANCE_SIGNATURE:-none}/.socket2.sock"
if command -v socat >/dev/null 2>&1 && [ -S "$SOCK" ]; then
  while read -r line; do
    case "$line" in
      workspace'>>'*|focusedmon'>>'*) publish "$(active)" ;;
    esac
  done < <(socat -u "UNIX-CONNECT:$SOCK" - 2>/dev/null)
fi
empty=0
while true; do
  cur=$(active)
  if [ -z "$cur" ]; then empty=$((empty + 1)); [ "$empty" -ge 30 ] && exit 1; else empty=0; publish "$cur"; fi
  sleep 1
done
