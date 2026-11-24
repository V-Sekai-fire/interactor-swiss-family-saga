# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The plan as a timeline: one row per family member, one bar per task they are on, laid out in time. Duties are inked, scouting is the accent colour, the selected task
# has a ring, and the task the checker refuses is outlined in the design system's "bad" colour.
extends Control

const Look = preload("res://look/look.gd")
const ROW := 22.0
const LEFT := 64.0

var state: RefCounted
var names: Array = []
var selected := -1
var flagged := -1

func refresh() -> void:
	queue_redraw()

func _draw() -> void:
	if state == null or state.world.is_empty():
		return
	var font := get_theme_default_font()
	var chars: int = state.world["chars"].size()
	var horizon := 20
	for t in range(state.task_count()):
		if state.is_done(t):
			horizon = max(horizon, int(state.picks[t]["start"]) + state.duration(t) + 2)
	var scale := (size.x - LEFT - 8.0) / float(horizon)
	for tick in range(0, horizon + 1, 5):
		var x := LEFT + float(tick) * scale
		draw_line(Vector2(x, 0.0), Vector2(x, ROW * chars), Color(Look.c("line"), 0.6), 1.0)
		draw_string(font, Vector2(x + 3.0, ROW * chars + 14.0), str(tick), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Look.c("mute"))
	for c in range(chars):
		var y := float(c) * ROW
		draw_rect(Rect2(0.0, y + 4.0, 8.0, 8.0), Look.c({"tank": "bad", "healer": "good", "damage": "warn", "support": "note"}[str(state.world["chars"][c]["role"])]))
		draw_string(font, Vector2(14.0, y + 14.0), names[c], HORIZONTAL_ALIGNMENT_LEFT, LEFT - 14.0, 12, Look.c("ink"))
		draw_line(Vector2(LEFT, y + ROW), Vector2(size.x, y + ROW), Color(Look.c("line"), 0.5), 1.0)
	for t in range(state.task_count()):
		if not state.is_done(t):
			continue
		var first := float(state.picks[t]["start"])
		var bar_width := float(state.duration(t)) * scale
		for c in state.members(t):
			var rect := Rect2(LEFT + first * scale, float(c) * ROW + 3.0, max(bar_width, 3.0), ROW - 6.0)
			var duty: bool = state.world["tasks"][t]["kind"] == "duty"
			draw_rect(rect, Look.c("ink") if duty else Look.c("lit"))
			draw_string(font, rect.position + Vector2(4.0, 11.0), str(t + 1), HORIZONTAL_ALIGNMENT_LEFT, rect.size.x, 11, Look.c("paper"))
			if t == selected:
				draw_rect(rect.grow(2.0), Look.c("ink"), false, 2.0)
			if t == flagged:
				draw_rect(rect.grow(3.0), Look.c("bad"), false, 2.0)
