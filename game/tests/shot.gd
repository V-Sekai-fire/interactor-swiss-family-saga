# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Renders the first screen once and saves it as a picture, so that the look can be read without a window in front of anyone.
# Run: godot --path . --script game/tests/shot.gd -- OUT.png [CHAPTER] [best|half]   (needs a renderer; the headless editor has none)
extends SceneTree

var frames := 0
var out := ""
var chapter := 0
var mode := ""
var scene: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	out = args[0] if args.size() > 0 else "shot.png"
	chapter = int(args[1]) - 1 if args.size() > 1 else 0
	mode = args[2] if args.size() > 2 else ""
	scene = load("res://game/scenes/main.tscn").instantiate()
	root.add_child(scene)



func _process(_delta: float) -> bool:
	frames += 1
	if frames == 3:
		scene.chapter = chapter # after the screen has built itself
		scene._open_chapter()
		if mode == "best":
			scene._best()
		elif mode == "half":
			# two tasks put together by hand: the first two members of the model's plan for each
			for t in [0, 1]:
				scene.selected = t
				for c in range(6):
					if (int(scene.state.best_plan["party"][t]) >> c) & 1 == 1:
						scene._member(c)
			scene._select(1)
		elif mode == "step1":
			pass
		elif mode == "step2":
			scene._choose(0) # one decision taken, so the second question is on screen
		elif mode == "step3":
			scene._choose(0)
			scene._choose(0)
		elif mode == "choose":
			# two choices taken: the first option, then the second
			scene._choose(0)
			scene._choose(1)
		elif mode == "hint":
			# a player who is stuck asks for three hints
			for _i in range(3):
				scene._hint()
		elif mode == "hand":
			# every required task put on its model members, started as the screen suggests: allowed, and slower than the best
			for t in range(scene.state.task_count()):
				if bool(scene.state.world["tasks"][t]["required"]):
					for c in range(6):
						if (int(scene.state.best_plan["party"][t]) >> c) & 1 == 1:
							scene.state.toggle_member(t, c)
			scene._refresh()
	if frames == 14:
		var image := root.get_texture().get_image()
		print("saved ", out, " ", image.get_size(), " result=", image.save_png(out))
		quit(0)
	return false
