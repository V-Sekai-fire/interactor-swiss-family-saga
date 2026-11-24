# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Renders the first screen once and saves it as a picture, so that the look can be read without a window in front of anyone.
# Run: godot --path . --script game/tests/shot.gd -- OUT.png [CHAPTER]   (needs a renderer; the headless editor has none)
extends SceneTree

var frames := 0
var out := ""
var chapter := 0
var scene: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "shot.png"
	chapter = int(args[1]) - 1 if args.size() > 1 else 0
	scene = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(scene)



func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		scene.chapter = chapter # after the screen has built itself
		scene._show()
	if frames == 14:
		var image := root.get_texture().get_image()
		print("saved ", out, " ", image.get_size(), " result=", image.save_png(out))
		quit(0)
	return false
