#!/usr/bin/env bash
# Проверки, которые не требуют Hyprland: синтаксис, shellcheck, JSON, theme/theme-gen в изолированном HOME,
# безопасность разбора .env, калькулятор лаунчера. Запуск: tests/run.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/dotfiles"
FAIL=0
ok()  { printf ' [ ok ] %s\n' "$1"; }
bad() { printf ' [FAIL] %s\n' "$1"; FAIL=$((FAIL + 1)); }
check() { local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else bad "$name"; fi; }

echo "== синтаксис bash =="
while IFS= read -r f; do check "bash -n ${f#"$ROOT"/}" bash -n "$f"; done < <(
  { find "$D/local/bin" "$D/config/quickshell/scripts" "$D/config/waybar" -type f \( -name '*.sh' -o -perm -u+x \); echo "$ROOT/install.sh"; echo "$ROOT/uninstall.sh"; } | sort -u)

echo "== shellcheck =="
if command -v shellcheck >/dev/null 2>&1; then
  while IFS= read -r f; do check "shellcheck ${f#"$ROOT"/}" shellcheck -S warning "$f"; done < <(
    { find "$D/local/bin" "$D/config/quickshell/scripts" "$D/config/waybar" -type f \( -name '*.sh' -o -perm -u+x \); echo "$ROOT/install.sh"; echo "$ROOT/uninstall.sh"; } | sort -u)
else echo " [skip] shellcheck не установлен"; fi

echo "== JSON =="
if command -v jq >/dev/null 2>&1; then
  while IFS= read -r f; do check "jq ${f#"$ROOT"/}" jq -e . "$f"; done < <(find "$D" -name '*.json' | sort)
  check "jq waybar/config.jsonc" jq -e . "$D/config/waybar/config.jsonc"
else echo " [skip] jq не установлен"; fi

echo "== Lua =="
if command -v luac5.4 >/dev/null 2>&1 || command -v luac >/dev/null 2>&1; then
  LUAC=$(command -v luac5.4 || command -v luac)
  check "luac -p monochrome.lua" "$LUAC" -p "$D/config/hypr/monochrome.lua"
else echo " [skip] luac не установлен"; fi

echo "== theme / theme-gen в изолированном HOME =="
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
export HOME="$TMP/home" XDG_RUNTIME_DIR="$TMP/run"
mkdir -p "$HOME/.config" "$HOME/.local/bin" "$XDG_RUNTIME_DIR"
cp -a "$D/config/." "$HOME/.config/"; cp -a "$D/local/bin/." "$HOME/.local/bin/"
export PATH="$HOME/.local/bin:$PATH"
check "theme-gen создаёт тему" theme-gen demo 200 50
check "theme-gen не перезаписывает без --force" bash -c 'theme-gen demo 10 10 | grep -q "уже есть"'
check "theme-gen отвергает плохое имя" bash -c '! theme-gen "a/b" 10 10'
check "theme-gen отвергает оттенок 400" bash -c '! theme-gen x 400 10'
mkdir -p "$HOME/.config/themes/wallpapers/demo"
if command -v convert >/dev/null 2>&1; then convert -size 8x8 xc:gray "$HOME/.config/themes/wallpapers/demo/a [1] & b.png"; fi
check "theme применяет сгенерированную тему" env THEME_NO_RELOAD=1 theme demo
check "colors.json корректен" jq -e .bg "$HOME/.config/themes/colors.json"
check "нет неподставленных {{...}} в результате" bash -c '! grep -rq "{{[A-Z0-9_]*}}" "$HOME/.config/waybar/style.css" "$HOME/.config/hypr/theme.lua"'
check "theme gray" env THEME_NO_RELOAD=1 theme gray
printf 'BG=10090c; touch %s/PWNED\n' "$TMP" > "$HOME/.config/themes/themes/evil.env"
check "тема с вредной строкой отвергнута" bash -c '! THEME_NO_RELOAD=1 theme evil'
check "вредная строка не выполнилась" test ! -e "$TMP/PWNED"

check "старая тема с TINT/SAT/GRAIN всё ещё применяется" bash -c 'cp "$HOME/.config/themes/themes/gray.env" "$HOME/.config/themes/themes/old.env"; printf "TINT=\"1.0, 1.0, 1.0\"\nSAT=0.0\nGRAIN=0.04\n" >> "$HOME/.config/themes/themes/old.env"; THEME_NO_RELOAD=1 theme old'

echo "== шейдера и автоблокировки в райсе нет =="
check "слово shader нигде в dotfiles не встречается" bash -c '! grep -rIli "shader" "$0/dotfiles"' "$ROOT"
check "hypridle не запускается из rice" bash -c '! grep -q "start hypridle" "$HOME/.local/bin/rice"'
check "supervise не сдаётся после падений" bash -c '
  supervise testfail false >/dev/null 2>&1 &
  sp=$!
  sleep 8
  if kill -0 "$sp" 2>/dev/null; then r=0; else r=1; fi
  kill -KILL "$sp" 2>/dev/null
  exit $r'

echo "== калькулятор лаунчера (без eval) =="
if command -v node >/dev/null 2>&1; then
  python3 - "$D/config/quickshell/Launcher.qml" "$TMP/calc.js" <<'PY'
import sys
s = open(sys.argv[1]).read()
a = s.index("  function evalExpr(src) {"); b = s.index("  function calc(q0")
body = s[a:b].replace("  function evalExpr", "function evalExpr", 1)
tests = [("2+3*4", 14), ("(2+3)*4", 20), ("2^3^2", 512), ("-2^2", -4), ("10%3", 1), ("2**3", 8)]
js = body + "\nlet bad = 0;\n"
for e, v in tests:
    js += "if (evalExpr(%r) !== %s) { console.log('неверно: %s'); bad++; }\n" % (e, v, e)
js += "for (const e of ['1+', '(1', '2 3', 'abc', 'process.exit()']) { try { evalExpr(e); console.log('должно быть ошибкой: ' + e); bad++; } catch (x) {} }\nprocess.exit(bad ? 1 : 0);\n"
open(sys.argv[2], "w").write(js)
PY
  check "evalExpr считает и отвергает мусор" node "$TMP/calc.js"
else echo " [skip] node не установлен"; fi

echo
if [ "$FAIL" -eq 0 ]; then echo "все проверки пройдены"; else echo "провалено проверок: $FAIL"; fi
exit "$FAIL"
