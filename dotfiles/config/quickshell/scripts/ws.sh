#!/usr/bin/env bash
state="${XDG_RUNTIME_DIR:-/tmp}/qs-prev-ws"
case "$1" in
  hide)
    id=$(hyprctl activeworkspace -j | grep -m1 '"id"' | tr -dc '0-9-')
    [ -n "$id" ] && [ "$id" != "99" ] && echo "$id" > "$state"
    hyprctl dispatch 'hl.dsp.focus({ workspace = 99 })'
    ;;
  restore)
    id=""
    [ -f "$state" ] && id=$(cat "$state")
    [ -n "$id" ] && hyprctl dispatch "hl.dsp.focus({ workspace = $id })"
    rm -f "$state"
    ;;
esac
