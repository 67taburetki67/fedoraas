#!/usr/bin/env bash
# round-image.sh <файл>: печатает путь к копии со скруглёнными углами
in="$1"
OUT="$HOME/.local/share/quickshell-notes/stickers"
mkdir -p "$OUT"
if command -v magick >/dev/null 2>&1; then IM=(magick); ID=(magick identify)
elif command -v convert >/dev/null 2>&1 && command -v identify >/dev/null 2>&1; then IM=(convert); ID=(identify)
else
  echo "NOTE:нет ImageMagick (sudo dnf install -y ImageMagick), углы не скруглены"
  echo "$in"
  exit 0
fi

ext=$(echo "${in##*.}" | tr 'A-Z' 'a-z')
base=$(basename "${in%.*}" | tr '[]' '__')
stamp=$(date +%s)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# ImageMagick принимает [ ] в имени за выбор кадра: обрабатываем копию с простым именем
orig="$in"
if ! cp -- "$in" "$tmp/input.$ext" 2>/dev/null; then echo "NOTE:не удалось прочитать файл"; echo "$orig"; exit 0; fi
in="$tmp/input.$ext"

if [ "$ext" = gif ]; then
  "${IM[@]}" "$in" -coalesce -resize '800x800>' "$tmp/src.gif" || { echo "NOTE:не удалось обработать GIF, добавлен оригинал"; echo "$orig"; exit 0; }
  src="$tmp/src.gif"
  out="$OUT/$base-$stamp-r.gif"
else
  "${IM[@]}" "${in}[0]" -resize '1600x1600>' "$tmp/src.png" || { echo "NOTE:не удалось обработать картинку, добавлен оригинал"; echo "$orig"; exit 0; }
  src="$tmp/src.png"
  out="$OUT/$base-$stamp-r.png"
fi

read -r W H < <("${ID[@]}" -format '%w %h\n' "${src}[0]" 2>/dev/null)
if [ -z "$W" ] || [ -z "$H" ]; then echo "$orig"; exit 0; fi
m=$(( W < H ? W : H ))
R=$(( m * 9 / 100 ))
[ "$R" -lt 10 ] && R=10
[ "$R" -gt 80 ] && R=80
"${IM[@]}" -size "${W}x${H}" xc:none -fill white -draw "roundrectangle 0,0 $((W-1)),$((H-1)) $R,$R" "$tmp/mask.png"

if [ "$ext" = gif ]; then
  "${IM[@]}" "$src" -coalesce null: "$tmp/mask.png" -compose DstIn -layers composite -set dispose background "$out"
else
  "${IM[@]}" "$src" -alpha set "$tmp/mask.png" -compose DstIn -composite "$out"
fi

if [ -s "$out" ]; then
  echo "$out"
else
  echo "NOTE:скругление не получилось, добавлена оригинальная картинка"
  echo "$orig"
fi
