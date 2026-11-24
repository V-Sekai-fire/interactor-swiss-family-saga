# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The island, drawn from a chapter's world. The whole island is always drawn: places the chapter does not use yet are faint, as unvisited ground. A place that has a task
# in this chapter is inked and carries a mark per task (a square for a duty, a ring for scouting, faint when optional). Paths over water are dashed and curved.
# Colours come from the design system.
extends Control

const Look = preload("res://look/look.gd")
const NAMES := ["Safety Bay", "Tentholm", "Falconhurst", "Woodlands", "Prospect Hill", "Shark Island", "Rockburg", "Cape Minster"]
# Where each place sits, as a share of the map's width and height.
const SPOTS := [Vector2(0.10, 0.74), Vector2(0.30, 0.66), Vector2(0.48, 0.42), Vector2(0.62, 0.20), Vector2(0.84, 0.34), Vector2(0.46, 0.86), Vector2(0.72, 0.70), Vector2(0.92, 0.62)]

var world: Dictionary = {}
var island_edges: Array = []
var selected_place := -1

func set_selected(place: int) -> void:
	selected_place = place
	queue_redraw()

func set_world(new_world: Dictionary, all_edges: Array) -> void:
	world = new_world
	island_edges = all_edges
	queue_redraw()

func _spot(index: int) -> Vector2:
	return Vector2(SPOTS[index].x * size.x, SPOTS[index].y * size.y)

# A quadratic curve bowed to one side, drawn as dashes.
func _dashed_curve(a: Vector2, b: Vector2, colour: Color) -> void:
	var middle := (a + b) / 2.0
	var bow := (b - a).orthogonal().normalized() * 38.0
	var points := PackedVector2Array()
	for i in range(25):
		var t := float(i) / 24.0
		points.append(a.lerp(middle + bow, t).lerp((middle + bow).lerp(b, t), t))
	for i in range(0, 24, 2):
		draw_line(points[i], points[i + 1], colour, 2.0)

func _draw() -> void:
	if world.is_empty():
		return
	var known: int = world["nodes"]
	for edge in island_edges:
		var a: int = int(edge[0]) - 1
		var b: int = int(edge[1]) - 1
		if a > b:
			continue # every path is listed both ways
		var seen := a < known and b < known
		var colour := Look.c("line") if seen else Color(Look.c("line"), 0.35)
		if str(edge[3]) == "water":
			_dashed_curve(_spot(a), _spot(b), Look.c("lit") if seen else Color(Look.c("lit"), 0.3))
		else:
			draw_line(_spot(a), _spot(b), colour, 3.0)
	var font := get_theme_default_font()
	for p in range(NAMES.size()):
		var here := _spot(p)
		var marks: Array = []
		for task in world["tasks"]:
			if int(task["at"]) - 1 == p:
				marks.append(task)
		var seen := p < known
		var used := not marks.is_empty()
		if p == selected_place:
			draw_circle(here, 22.0, Color(Look.c("lit"), 0.25))
		draw_circle(here, 15.0, Look.c("card"))
		draw_arc(here, 15.0, 0.0, TAU, 40, Look.c("ink") if used else (Look.c("line") if seen else Color(Look.c("line"), 0.5)), 2.0)
		var label_colour := Look.c("ink") if used else (Look.c("mute") if seen else Color(Look.c("mute"), 0.5))
		draw_string(font, here + Vector2(-60.0, 38.0), NAMES[p], HORIZONTAL_ALIGNMENT_CENTER, 120.0, 13, label_colour)
		for i in range(marks.size()):
			var angle := -PI / 2.0 + float(i) * 0.9 - 0.45 * float(marks.size() - 1)
			var spot := here + Vector2(cos(angle), sin(angle)) * 27.0
			var colour := Look.c("ink") if bool(marks[i]["required"]) else Look.c("mute")
			if marks[i]["kind"] == "duty":
				draw_rect(Rect2(spot - Vector2(5.0, 5.0), Vector2(10.0, 10.0)), colour)
			else:
				draw_arc(spot, 5.0, 0.0, TAU, 20, colour, 2.0)
