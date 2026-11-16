#!/usr/bin/env bash
n="$1"
read -r cur < "${XDG_RUNTIME_DIR:-/tmp}/ws-active" 2>/dev/null
if [ "$cur" = "$n" ]; then cls=active; else cls=idle; fi
echo "{\"text\":\"$n\",\"class\":\"$cls\"}"
