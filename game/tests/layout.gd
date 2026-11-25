# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Dumps the layout of every control on screen in every state a player can reach (each chapter at each decision, the end screen, and the free board with the first and last task),
# as JSON for tools/layout_check.lean to verify. Run: godot --headless --path . --script game/tests/layout.gd -- OUT.json
extends SceneTree

const MainScene := preload("res://game/scenes/main.tscn")
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
	var nodes: Array = []
	_collect(scene, "", nodes)
	states.append({"name": name, "nodes": nodes})

func _collect(node: Node, parent_path: String, nodes: Array) -> void:
	var here := parent_path
	if node is Control and node.is_visible_in_tree():
		var control: Control = node
		var rect := control.get_global_rect()
		var minimum := control.get_combined_minimum_size()
		var entry := {"path": str(scene.get_path_to(control)), "parent": parent_path, "cls": control.get_class(), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"min": [minimum.x, minimum.y], "container": control is Container, "text": "", "text_width": 0.0, "autowrap": false, "lines": 0, "visible_lines": 0}
		if control is Label or control is Button:
			var text: String = control.text
			var font: Font = control.get_theme_font("font")
			var size: int = control.get_theme_font_size("font_size")
			entry["text"] = text
			entry["text_width"] = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x if text.find("\n") < 0 else _longest_line(font, text, size)
			entry["autowrap"] = control.autowrap_mode != TextServer.AUTOWRAP_OFF
		if control is Label:
			entry["lines"] = control.get_line_count()
			entry["visible_lines"] = control.get_visible_line_count()
		nodes.append(entry)
		here = entry["path"]
	for child in node.get_children():
		_collect(child, here, nodes)

func _longest_line(font: Font, text: String, size: int) -> float:
	var widest := 0.0
	for line in text.split("\n"):
		widest = max(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest
