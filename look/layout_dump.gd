# The rectangle of every visible control under a node, as the dictionary tools/layout_check.lean reads.
#   var state := LayoutDump.state("chapter 1", scene_root, scene_root)   # then: JSON.stringify({"window": [w, h], "states": [state, ...]})
class_name LayoutDump
extends RefCounted

static func state(name: String, scene: Node, from: Node) -> Dictionary:
	var nodes: Array = []
	_collect(scene, from, "", nodes)
	return {"name": name, "nodes": nodes}

static func _collect(scene: Node, node: Node, parent_path: String, nodes: Array) -> void:
	var here := parent_path
	if node is Control and node.is_visible_in_tree():
		var control: Control = node
		var rect := control.get_global_rect()
		var minimum := control.get_combined_minimum_size()
		var entry := {"path": str(scene.get_path_to(control)), "parent": parent_path, "cls": control.get_class(), "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"min": [minimum.x, minimum.y], "container": control is Container, "text": "", "text_width": 0.0, "autowrap": false, "lines": 0, "visible_lines": 0}
		if control is Label or control is Button:
			var font: Font = control.get_theme_font("font")
			var size: int = control.get_theme_font_size("font_size")
			entry["text"] = control.text
			entry["text_width"] = _widest(font, control.text, size)
			entry["autowrap"] = control.autowrap_mode != TextServer.AUTOWRAP_OFF
		if control is Label:
			entry["lines"] = control.get_line_count()
			entry["visible_lines"] = control.get_visible_line_count()
		nodes.append(entry)
		here = entry["path"]
	for child in node.get_children():
		_collect(scene, child, here, nodes)

static func _widest(font: Font, text: String, size: int) -> float:
	var widest := 0.0
	for line in text.split("\n"):
		widest = max(widest, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return widest
