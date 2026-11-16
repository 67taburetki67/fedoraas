#!/usr/bin/env bash
D="$HOME/.local/share/quickshell-notes/files"
mkdir -p "$D"
RUN="${XDG_RUNTIME_DIR:-/tmp}"
PID="$RUN/notes-rec.pid"
PLAYPID="$RUN/notes-play.pid"
ts=$(date +%Y%m%d-%H%M%S)

case "$1" in
  paste)
    types=$(wl-paste --list-types 2>/dev/null)
    if echo "$types" | grep -q '^image/gif'; then ext=gif; mime=image/gif
    elif echo "$types" | grep -q '^image/png'; then ext=png; mime=image/png
    elif echo "$types" | grep -q '^image/jpeg'; then ext=jpg; mime=image/jpeg
    elif echo "$types" | grep -q '^image/webp'; then ext=webp; mime=image/webp
    else echo "ERR:в буфере обмена нет картинки"; exit 0; fi
    f="$D/clip-$ts.$ext"
    wl-paste --type "$mime" > "$f" 2>/dev/null
    if [ -s "$f" ]; then echo "$f"; else rm -f "$f"; echo "ERR:не удалось прочитать буфер"; fi
    ;;
  pick)
    list=$(find "$HOME/Pictures" "$HOME/Downloads" "$HOME/Videos" "$HOME/Music" "$HOME/Documents" -maxdepth 4 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.wav' -o -iname '*.ogg' -o -iname '*.mp3' -o -iname '*.flac' -o -iname '*.m4a' -o -iname '*.opus' \) 2>/dev/null | sort)
    if [ -z "$list" ]; then echo "ERR:нет подходящих файлов в Pictures, Downloads, Videos, Music, Documents"; exit 0; fi
    sel=$(echo "$list" | fuzzel --dmenu --prompt "файл: " 2>/dev/null)
    [ -z "$sel" ] && exit 0
    f="$D/$ts-$(basename "$sel")"
    if cp -- "$sel" "$f"; then echo "$f"; else echo "ERR:не удалось скопировать файл"; fi
    ;;
  record)
    f="$D/voice-$ts.wav"
    if command -v pw-record >/dev/null; then
      pw-record --rate 24000 --channels 1 "$f" 2>/dev/null &
    elif command -v arecord >/dev/null; then
      arecord -q -f S16_LE -r 24000 -c 1 -t wav "$f" 2>/dev/null &
    else
      echo "ERR:нет pw-record и arecord"; exit 0
    fi
    echo $! > "$PID"
    wait $!
    rm -f "$PID"
    if [ -s "$f" ]; then echo "$f"; else rm -f "$f"; echo "ERR:запись пустая, проверь микрофон"; fi
    ;;
  stop)
    [ -f "$PID" ] && kill -INT "$(cat "$PID")" 2>/dev/null
    ;;
  play)
    f="$2"
    echo $$ > "$PLAYPID"
    for p in pw-play paplay; do
      if command -v "$p" >/dev/null; then exec "$p" "$f"; fi
    done
    command -v mpv >/dev/null && exec mpv --no-video --really-quiet "$f"
    command -v ffplay >/dev/null && exec ffplay -nodisp -autoexit -loglevel quiet "$f"
    echo "ERR:нет проигрывателя (pw-play, paplay, mpv)"
    ;;
  stopplay)
    [ -f "$PLAYPID" ] && kill "$(cat "$PLAYPID")" 2>/dev/null
    ;;
esac
exit 0
