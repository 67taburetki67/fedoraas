#!/usr/bin/env bash
pactl --format=json list sinks 2>/dev/null
echo
echo "##default"
pactl get-default-sink 2>/dev/null
