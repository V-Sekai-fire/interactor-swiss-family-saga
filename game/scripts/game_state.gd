# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The player's plan for one chapter, and what the checker says about it. No drawing here, so the rules of play can be tested without a window.
# A task is done when someone is put on it. Putting a member on a task starts it as early as that member can be there, after what they already do; the player
# moves it from there. Any plan may be built (off the rails is allowed); the checker names the first rule a plan breaks.
extends RefCounted

const CheckerScript := preload("res://game/scripts/checker.gd")

var world: Dictionary = {}
var best_plan: Dictionary = {}
var best_objective := 0
var picks: Array = []        # per task: {"party": bit mask, "start": int, "performance": bool}
var distances: Array = []    # per character, the shortest travel times between places

func load_chapter(data: Dictionary) -> void:
	world = data["world"]
	best_plan = data["cases"][0]["plan"]
	best_objective = int(data["optimum"])
	distances = []
	for c in world["chars"]:
		distances.append(CheckerScript.distances(world, c))
	picks = []
	for _task in world["tasks"]:
		picks.append({"party": 0, "start": 0, "performance": false})

func task_count() -> int:
	return world["tasks"].size()

func members(t: int) -> Array:
	var out: Array = []
	for c in range(world["chars"].size()):
		if (int(picks[t]["party"]) >> c) & 1 == 1:
			out.append(c)
	return out

func is_done(t: int) -> bool:
	return int(picks[t]["party"]) != 0

func duration(t: int) -> int:
	return CheckerScript.duration(world, plan(), t)

# Puts a member on a task or takes them off it.
func toggle_member(t: int, c: int) -> void:
	var was_done := is_done(t)
	picks[t]["party"] = int(picks[t]["party"]) ^ (1 << c)
	if not is_done(t):
		picks[t]["start"] = 0
		picks[t]["performance"] = false
	elif not was_done or _earliest(t) > int(picks[t]["start"]):
		picks[t]["start"] = _earliest(t)
	_respect_order()

# Where a task can start at the soonest: when every member can be there, after the other tasks they are on.
func _earliest(t: int) -> int:
	var task: Dictionary = world["tasks"][t]
	var at: int = int(task["at"]) - 1
	var soonest := int(task["release"])
	for c in members(t):
		soonest = max(soonest, distances[c][int(world["chars"][c]["home"]) - 1][at])
		for u in range(task_count()):
			if u == t or not is_done(u) or (int(picks[u]["party"]) >> c) & 1 == 0:
				continue
			var gap: int = int(world["chars"][c]["cooldown"]) if task["kind"] == "duty" and world["tasks"][u]["kind"] == "duty" else 0
			soonest = max(soonest, int(picks[u]["start"]) + duration(u) + distances[c][int(world["tasks"][u]["at"]) - 1][at] + gap)
	# a task that must wait for another starts after it is finished
	for pair in world["pairs"]:
		var before: int = int(pair[0]) - 1
		if int(pair[1]) - 1 == t and is_done(before):
			soonest = max(soonest, int(picks[before]["start"]) + duration(before))
	return soonest

func set_start(t: int, start: int) -> void:
	if is_done(t):
		picks[t]["start"] = max(0, start)
		_respect_order()

# A task that has to wait for another is moved after it, however the player filled them in.
func _respect_order() -> void:
	var moved := true
	while moved:
		moved = false
		for pair in world["pairs"]:
			var before: int = int(pair[0]) - 1
			var after: int = int(pair[1]) - 1
			if is_done(before) and is_done(after) and int(picks[after]["start"]) < int(picks[before]["start"]) + duration(before):
				picks[after]["start"] = int(picks[before]["start"]) + duration(before)
				moved = true

func set_performance(t: int, on: bool) -> void:
	if is_done(t) and world["tasks"][t]["kind"] == "scout":
		picks[t]["performance"] = on

func clear_task(t: int) -> void:
	picks[t] = {"party": 0, "start": 0, "performance": false}

func clear_all() -> void:
	for t in range(task_count()):
		clear_task(t)

# The model's best plan, as picks.
func load_best() -> void:
	for t in range(task_count()):
		picks[t] = {"party": int(best_plan["party"][t]) if best_plan["done"][t] else 0, "start": int(best_plan["start"][t]) if best_plan["done"][t] else 0, "performance": best_plan["how"][t] == "PERFORMANCE"}

# The picks as a plan the checker reads.
func plan() -> Dictionary:
	var done: Array = []
	var party: Array = []
	var how: Array = []
	var arm: Array = []
	var start: Array = []
	for t in range(task_count()):
		var d := is_done(t)
		var perform: bool = d and bool(picks[t]["performance"]) and world["tasks"][t]["kind"] == "scout"
		done.append(d)
		party.append(int(picks[t]["party"]))
		how.append("PERFORMANCE" if perform else "QUICK")
		arm.append("BOTH" if (perform or world["tasks"][t]["kind"] == "duty") else "LEFT")
		start.append(int(picks[t]["start"]) if d else 0)
	return {"done": done, "party": party, "how": how, "arm": arm, "start": start}

# The checker's verdict with the score: higher is better, the best plan scores best_score().
func verdict() -> Dictionary:
	var result: Dictionary = CheckerScript.check(world, plan())
	if result["allowed"]:
		result["score"] = -int(result["objective"])
	return result

func best_score() -> int:
	return -best_objective

func done_count() -> int:
	var n := 0
	for t in range(task_count()):
		if is_done(t):
			n += 1
	return n
