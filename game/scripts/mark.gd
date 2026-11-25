# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# A small drawn mark: a filled square (a duty), a ring (scouting), a star or an empty star. They are drawn, not typed, because the design system's fonts carry no
# symbols and a browser has no system font to fall back on.
extends Control

const Look = preload("res://look/look.gd")

var shape := "duty"

func _init(kind: String = "duty") -> void:
	shape = kind
	custom_minimum_size = Vector2(16, 16)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_shape(kind: String) -> void:
	shape = kind
	queue_redraw()

func _draw() -> void:
	var middle := size / 2.0
	match shape:
		"duty":
			draw_rect(Rect2(middle - Vector2(5, 5), Vector2(10, 10)), Look.c("ink"))
		"scout":
			draw_arc(middle, 5.0, 0.0, TAU, 24, Look.c("ink"), 2.0)
		"star", "star_empty":
			var points := PackedVector2Array()
			for i in range(10):
				var radius := 7.0 if i % 2 == 0 else 3.0
				var angle := -PI / 2.0 + float(i) * PI / 5.0
				points.append(middle + Vector2(cos(angle), sin(angle)) * radius)
			if shape == "star":
				draw_colored_polygon(points, Look.c("warn"))
			else:
				points.append(points[0])
				draw_polyline(points, Look.c("line"), 1.5)
