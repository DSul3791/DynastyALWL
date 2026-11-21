extends Node
# Processed after every other node (a very high process_priority): marks the end of the frame's process step for the slow-frame split in
# frame_probe.gd (Dave 21 Nov 2026, lag while running).

const FrameProbe := preload("res://src/debug/frame_probe.gd")


func _process(_delta: float) -> void:
	FrameProbe.process_end()
