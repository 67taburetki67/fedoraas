#!/usr/bin/env bash
case "$1" in
  volup)   wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+ ;;
  voldown) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- ;;
  mute)    wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
  briup)   brightnessctl -e4 -n2 set 5%+ >/dev/null ;;
  bridown) brightnessctl -e4 -n2 set 5%- >/dev/null ;;
esac
case "$1" in
  vol*|mute)
    v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
    pct=$(echo "$v" | awk '{printf "%.0f", $2*100}')
    if echo "$v" | grep -q MUTED; then kind=muted; else kind=vol; fi
    quickshell ipc call osd show "$kind" "${pct:-0}" ;;
  bri*)
    pct=$(brightnessctl -m 2>/dev/null | head -1 | cut -d, -f4 | tr -d '%')
    quickshell ipc call osd show bri "${pct:-0}" ;;
esac
