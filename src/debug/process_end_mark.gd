extends Node

# Runs after every other _process (process_priority at the top): stamps the end of the frame's scripts, so freeze_watch.gd can tell script
# time from the deferred calls and engine work that follow before the draw (Lane A 26 Nov 2026: 100-137 ms "process" parts with 10-16 ms
# of named pieces). Diagnostics only.

const FreezeWatchScript := preload("res://src/debug/freeze_watch.gd")


func _ready() -> void:
	process_priority = 1 << 30


func _process(_delta: float) -> void:
	FreezeWatchScript.process_end_mark()
