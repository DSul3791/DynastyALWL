#!/bin/bash
# Machine-wide limit on heavy Godot jobs (Tyler, 31 Oct 2026): at most GODOT_SLOTS (default 3) test or rig jobs run at once on this PC, across ALL sessions and
# worktrees, because 26 at once made timing tests meaningless and crashed jobs (exit 139).
#   as a wrapper:  tools/godot_slot.sh godot --headless --path . --script res://...      (waits for a free slot, runs, frees it)
#   sourced:       . tools/godot_slot.sh; slot_acquire; ...; slot_release              (tools/run_one_test.sh does this)
# Slots are folders in $GODOT_SLOT_DIR (default $TEMP/dynasty_godot_slots); a slot belongs to the shell that made it (its pid is written inside) and is
# taken over when that shell is gone (a crashed job never blocks the others). Nothing is ever killed. Waits at most GODOT_SLOT_WAIT seconds (default 3600),
# then runs anyway so a stuck slot cannot hang a gate.
#   GODOT_SLOTS=0        switch the guard off (opt-out)
#   GODOT_SLOTS=N        allow N at once
_SLOT_DIR="${GODOT_SLOT_DIR:-${TEMP:-${TMPDIR:-/tmp}}/dynasty_godot_slots}"
_SLOT_MINE=""

slot_acquire() {
	local max="${GODOT_SLOTS:-3}" waited=0 limit="${GODOT_SLOT_WAIT:-3600}" i p
	[ "$max" -le 0 ] 2>/dev/null && return 0
	mkdir -p "$_SLOT_DIR" 2>/dev/null || return 0
	while true; do
		for i in $(seq 1 "$max"); do
			if mkdir "$_SLOT_DIR/$i" 2>/dev/null; then echo $$ > "$_SLOT_DIR/$i/pid"; _SLOT_MINE="$_SLOT_DIR/$i"; return 0; fi
			p=$(cat "$_SLOT_DIR/$i/pid" 2>/dev/null)
			# a slot whose owner is gone (or never wrote its pid for 60 s) is taken over
			if [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null; then rm -rf "$_SLOT_DIR/$i" 2>/dev/null; continue; fi
			if [ -z "$p" ] && [ -d "$_SLOT_DIR/$i" ] && [ -n "$(find "$_SLOT_DIR/$i" -maxdepth 0 -mmin +1 2>/dev/null)" ]; then rm -rf "$_SLOT_DIR/$i" 2>/dev/null; continue; fi
		done
		[ "$waited" -ge "$limit" ] && return 0
		sleep 2; waited=$((waited + 2))
	done
}

slot_release() {
	[ -n "$_SLOT_MINE" ] && rm -rf "$_SLOT_MINE" 2>/dev/null
	_SLOT_MINE=""
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
	[ $# -eq 0 ] && { sed -n 2,12p "$0"; exit 2; }
	slot_acquire
	trap slot_release EXIT
	"$@"
fi
