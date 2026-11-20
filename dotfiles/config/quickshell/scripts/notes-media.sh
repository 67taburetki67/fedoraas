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
    rpid=$!
    echo "$rpid" > "$PID"
    wait "$rpid"
    [ "$(cat "$PID" 2>/dev/null)" = "$rpid" ] && rm -f "$PID"
    if [ -s "$f" ]; then echo "$f"; else rm -f "$f"; echo "ERR:запись пустая, проверь микрофон"; fi
    ;;
  stop)
    # убиваем только процесс записи: pid-файл мог остаться от прошлого сеанса
    pid=$(cat "$PID" 2>/dev/null)
    case "$(cat "/proc/${pid:-0}/comm" 2>/dev/null)" in
      pw-record|arecord) kill -INT "$pid" 2>/dev/null ;;
    esac
    ;;
  play)
    f="$2"
    player=()
    if command -v pw-play >/dev/null; then player=(pw-play "$f")
    elif command -v paplay >/dev/null; then player=(paplay "$f")
    elif command -v mpv >/dev/null; then player=(mpv --no-video --really-quiet "$f")
    elif command -v ffplay >/dev/null; then player=(ffplay -nodisp -autoexit -loglevel quiet "$f")
    else echo "ERR:нет проигрывателя (pw-play, paplay, mpv)"; exit 0
    fi
    # без exec: после конца воспроизведения скрипт сам удаляет pid-файл, и «стоп» не заденет чужой процесс
    "${player[@]}" &
    ppid=$!
    echo "$ppid" > "$PLAYPID"
    trap 'kill "$ppid" 2>/dev/null' TERM INT
    wait "$ppid"
    [ "$(cat "$PLAYPID" 2>/dev/null)" = "$ppid" ] && rm -f "$PLAYPID"
    ;;
  stopplay)
    pid=$(cat "$PLAYPID" 2>/dev/null)
    case "$(cat "/proc/${pid:-0}/comm" 2>/dev/null)" in
      pw-play|paplay|mpv|ffplay) kill "$pid" 2>/dev/null ;;
      *) rm -f "$PLAYPID" ;;
    esac
    ;;
esac
exit 0
