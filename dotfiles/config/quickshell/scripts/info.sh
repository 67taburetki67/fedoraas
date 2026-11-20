#!/usr/bin/env bash
disk=$(df -h --output=pcent,avail "$HOME" | tail -1 | awk '{print $1" · "$2" free"}')
up=$(uptime -p | sed 's/^up //')
net=$(ip -4 -o addr show scope global | awk '{print $2" "$4}' | head -1)
echo "$disk|$up|${net:-offline}"
