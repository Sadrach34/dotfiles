#!/usr/bin/env bash
# Assign workspaces to monitors dynamically: 5 WS per monitor, overflow to primary.

mapfile -t monitors < <(hyprctl monitors -j 2>/dev/null | jq -r '.[].name' 2>/dev/null || true)
num=${#monitors[@]}

if (( num == 0 )); then
	echo "ERROR: no monitors detected" >&2
	exit 1
fi

primary="${monitors[0]}"
assign() { hyprctl keyword workspace "$1,monitor:$2" > /dev/null 2>&1; }

if (( num == 1 )); then
	for i in $(seq 1 10); do assign "$i" "$primary"; done

elif (( num == 2 )); then
	secondary="${monitors[1]}"
	for i in $(seq 1 5);   do assign "$i" "$primary";   done
	for i in $(seq 6 10);  do assign "$i" "$secondary"; done
	for i in $(seq 11 20); do assign "$i" "$primary";   done

else
	for idx in "${!monitors[@]}"; do
		mon="${monitors[$idx]}"
		start=$(( idx * 5 + 1 ))
		for i in $(seq "$start" $(( start + 4 ))); do
			assign "$i" "$mon"
		done
	done
	last=$(( num * 5 ))
	for i in $(seq $(( last + 1 )) 20); do assign "$i" "$primary"; done
fi
