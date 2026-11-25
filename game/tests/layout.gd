# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Dumps the layout of every control on screen in every state a player can reach (each chapter at each decision, the end screen, and the free board with the first and last task),
# as JSON for tools/layout_check.lean to verify. Run: godot --headless --path . --script game/tests/layout.gd -- OUT.json
extends SceneTree

const MainScene := preload("res://game/scenes/main.tscn")
const LayoutDump := preload("res://look/layout_dump.gd")
var out_path := "layout.json"
var states: Array = []
var scene: Control

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_path = args[0]
	root.size = Vector2i(1180, 780)
	scene = MainScene.instantiate()
	root.add_child(scene)
	await _settle()
	for chapter in range(8):
		scene.chapter = chapter
		scene._open_chapter()
		scene.edit_card.visible = false
		scene.choice_card.visible = true
		await _settle()
		var n := 0
		while not scene.state.choices_done():
			n += 1
			await _dump("ch%d decision %d" % [chapter + 1, n])
			scene._choose(0)
			await _settle()
		await _dump("ch%d all chosen" % (chapter + 1))
		scene.edit_card.visible = true
		scene.choice_card.visible = false
		for t in [0, scene.state.task_count() - 1]:
			scene._select(t)
			await _dump("ch%d free board, task %d" % [chapter + 1, t + 1])
		scene.edit_card.visible = false
		scene.choice_card.visible = true
	var file := FileAccess.open(out_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"window": [1180, 780], "states": states}))
	print("layout: %d states written to %s" % [states.size(), out_path])
	quit()

func _settle() -> void:
	await process_frame
	await process_frame

func _dump(name: String) -> void:
	await _settle()
	states.append(LayoutDump.state(name, scene, scene))
