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
func _earliest(t: int, among: Array = []) -> int:
	var task: Dictionary = world["tasks"][t]
	var others: Array = among if not among.is_empty() else range(task_count())
	var at: int = int(task["at"]) - 1
	var soonest := int(task["release"])
	for c in members(t):
		soonest = max(soonest, distances[c][int(world["chars"][c]["home"]) - 1][at])
		for u in others:
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

# Where a plan lost to the model's best, exactly. The objective is time_weight * end - bonuses - point_weight * points, so the gap to the best is the cost of the extra time
# plus, task by task, what the best plan earns on that task and this one does not. The parts add up to the gap, so none of it is an estimate.
func regret() -> Dictionary:
	var mine: Dictionary = plan()
	var result: Dictionary = verdict()
	if not result["allowed"]:
		return {}
	var best_end := 0
	for t in range(task_count()):
		if best_plan["done"][t]:
			best_end = max(best_end, int(best_plan["start"][t]) + CheckerScript.duration(world, best_plan, t))
	var time_cost: int = int(world["time_weight"]) * (int(result["end"]) - best_end)
	var losses: Array = []
	for t in range(task_count()):
		var gain_best := _value(best_plan, t)
		var gain_mine := _value(mine, t)
		if gain_best != gain_mine:
			var why := "left out"
			if bool(mine["done"][t]) and bool(best_plan["done"][t]):
				why = "not performed" if mine["how"][t] != best_plan["how"][t] else "different"
			elif bool(mine["done"][t]):
				why = "extra"
			losses.append({"task": t, "loss": gain_best - gain_mine, "why": why})
	losses.sort_custom(func(a, b): return int(a["loss"]) > int(b["loss"]))
	return {"gap": best_score() - int(result["score"]), "time_cost": time_cost, "end": int(result["end"]), "best_end": best_end, "losses": losses}

# What a task is worth in a plan: its points and, for a duty or a performed scout, its bonus.
func _value(p: Dictionary, t: int) -> int:
	if not bool(p["done"][t]):
		return 0
	var task: Dictionary = world["tasks"][t]
	var v: int = int(world["point_weight"]) * int(task["points"])
	if task["kind"] == "duty" or p["how"][t] == "PERFORMANCE":
		v += int(task["bonus"])
	return v

# The soonest a task can start with the people on it without clashing with anything else they or the place are doing: after they can be there, after the tasks it
# waits for, and in a gap where nobody is double-booked and the place has room.
func earliest_start(t: int) -> int:
	if not is_done(t):
		return 0
	var task: Dictionary = world["tasks"][t]
	var at: int = int(task["at"]) - 1
	var s := int(task["release"])
	for c in members(t):
		s = max(s, distances[c][int(world["chars"][c]["home"]) - 1][at])
	for pair in world["pairs"]:
		if int(pair[1]) - 1 == t and is_done(int(pair[0]) - 1):
			s = max(s, int(picks[int(pair[0]) - 1]["start"]) + duration(int(pair[0]) - 1))
	var others: Array = []
	for u in range(task_count()):
		if u != t and is_done(u):
			others.append(u)
	var limit := s + 2000
	while s < limit:
		if _free_at(t, s, others):
			return s
		s += 1
	return int(picks[t]["start"])

# Whether a task could start at this time without any member being in two places and without crowding the place.
func _free_at(t: int, start: int, others: Array) -> bool:
	var task: Dictionary = world["tasks"][t]
	var at: int = int(task["at"]) - 1
	var length := duration(t)
	for c in members(t):
		for u in others:
			if (int(picks[u]["party"]) >> c) & 1 == 0:
				continue
			var there: int = int(world["tasks"][u]["at"]) - 1
			var gap: int = int(world["chars"][c]["cooldown"]) if task["kind"] == "duty" and world["tasks"][u]["kind"] == "duty" else 0
			var after_u: bool = start >= int(picks[u]["start"]) + duration(u) + distances[c][there][at] + gap
			var before_u: bool = start + length + distances[c][at][there] + gap <= int(picks[u]["start"])
			if not (after_u or before_u):
				return false
	var neighbours: Array = []
	for u in others:
		if int(world["tasks"][u]["zone"]) == int(task["zone"]):
			neighbours.append(u)
	return _zone_fits(t, start, neighbours)

# Moves a task to the soonest it can start.
func start_earliest(t: int) -> void:
	if is_done(t):
		picks[t]["start"] = earliest_start(t)
		_respect_order()

# Re-times every task as early as it can go, in the order they now start, keeping who does what.
func tidy() -> void:
	var order: Array = []
	for t in range(task_count()):
		if is_done(t):
			order.append(t)
	order.sort_custom(func(a, b): return int(picks[a]["start"]) < int(picks[b]["start"]) or (int(picks[a]["start"]) == int(picks[b]["start"]) and a < b))
	var placed: Array = []
	for t in order:
		var start := _earliest(t, placed) if not placed.is_empty() else _earliest(t, [t])
		while not _zone_fits(t, start, placed) and start < 10000:
			start += 1
		picks[t]["start"] = start
		placed.append(t)
		_respect_order()

# One more correct piece of the model's best plan: the first task, in time order, that is not yet as the best plan has it. Returns what it did.
func hint() -> Dictionary:
	var order: Array = []
	for t in range(task_count()):
		if bool(best_plan["done"][t]):
			order.append(t)
	order.sort_custom(func(a, b): return int(best_plan["start"][a]) < int(best_plan["start"][b]) or (int(best_plan["start"][a]) == int(best_plan["start"][b]) and a < b))
	for t in order:
		var want_party := int(best_plan["party"][t])
		var want_start := int(best_plan["start"][t])
		var want_performance: bool = best_plan["how"][t] == "PERFORMANCE"
		if int(picks[t]["party"]) != want_party or int(picks[t]["start"]) != want_start or bool(picks[t]["performance"]) != want_performance:
			picks[t] = {"party": want_party, "start": want_start, "performance": want_performance}
			return {"task": t, "party": want_party, "start": want_start, "performance": want_performance}
	return {}

# How far through the must-do tasks the player is.
func required_total() -> int:
	var n := 0
	for t in range(task_count()):
		if bool(world["tasks"][t]["required"]):
			n += 1
	return n

func required_placed() -> int:
	var n := 0
	for t in range(task_count()):
		if bool(world["tasks"][t]["required"]) and is_done(t):
			n += 1
	return n

# One to three stars, kind on purpose: a plan that works earns a star at two fifths of the best score, two at seven tenths, three only at the best.
func stars() -> int:
	var v: Dictionary = verdict()
	if not v["allowed"]:
		return 0
	var ratio := float(v["score"]) / float(best_score())
	if int(v["score"]) >= best_score():
		return 3
	if ratio >= 0.7:
		return 2
	return 1 if ratio >= 0.4 else 0

# Whether a task started at this time still fits in its place with the tasks already put there (a zone holds a number of arms at once).
func _zone_fits(t: int, start: int, placed: Array) -> bool:
	var zone: int = int(world["tasks"][t]["zone"])
	var capacity: int = int(world["zones"][zone - 1])
	var mine: Dictionary = plan()
	var starts: Dictionary = {t: start}
	for u in placed:
		if int(world["tasks"][u]["zone"]) == zone:
			starts[u] = int(picks[u]["start"])
	for moment in starts.values():
		var arms := 0
		for v in starts.keys():
			if int(starts[v]) <= moment and moment < int(starts[v]) + duration(v):
				arms += CheckerScript.usage(world, mine, v)
		if arms > capacity:
			return false
	return true

# ---- Two choices at a time ---------------------------------------------------------------------------------------------------------------------------------------
# The chapter as a run of decisions. For each task the model's best plan does, taken in the order it starts them, the player picks one of two options: what the best plan
# does there, or an alternative that still works but earns less. Both are scored by finishing the rest of the plan the way the best plan would, so the cost of a choice is exact.
var step_order: Array = []
var step_index := 0
var current_options: Array = []
var candidate_losses: Array = []
# A decision is only worth asking when the wrong answer costs this much of the score; smaller differences are carried out for the player.
const MIN_COST := 5

# Starts the run of decisions on an empty plan.
func begin_choices() -> void:
	clear_all()
	step_order = []
	for t in range(task_count()):
		if bool(best_plan["done"][t]):
			step_order.append(t)
	step_order.sort_custom(func(a, b): return int(best_plan["start"][a]) < int(best_plan["start"][b]) or (int(best_plan["start"][a]) == int(best_plan["start"][b]) and a < b))
	step_index = 0
	_prepare_step()

func choices_done() -> bool:
	return step_index >= step_order.size()

# The step in front of the player: {"task", "index", "total", "options": [two options]}, or {} when the run is over.
func current_step() -> Dictionary:
	if choices_done():
		return {}
	return {"task": step_order[step_index], "index": step_index, "total": step_order.size(), "options": current_options, "kind": str(current_options[0].get("kind", current_options[1].get("kind", "who")))}

# Takes the option the player picked (0 or 1); returns what it cost against the best way to carry on.
func choose(k: int) -> Dictionary:
	var option: Dictionary = current_options[k]
	var loss: int = int(option["loss"])
	var note := "That is what the best plan does here." if loss == 0 else "That works, but it costs %d against the best plan: %s." % [loss, option["why"]]
	_apply(step_order[step_index], option)
	step_index += 1
	_prepare_step()
	return {"loss": loss, "note": note}

func _apply(t: int, option: Dictionary) -> void:
	if bool(option.get("skip", false)):
		clear_task(t)
		return
	picks[t] = {"party": int(option["party"]), "start": int(option["start"]), "performance": bool(option["performance"])}
	_respect_order()

# Builds the two options for the current step, skipping steps that offer no real alternative.
func _prepare_step() -> void:
	current_options = []
	while not choices_done():
		var t: int = step_order[step_index]
		var good := _option_for(t, int(best_plan["party"][t]), best_plan["how"][t] == "PERFORMANCE", -1, false)
		var good_score := _completion_score(t, good)
		good["loss"] = 0
		good["why"] = ""
		var alt := _best_alternative(t, good_score)
		if alt.is_empty():
			_apply(t, good) # nothing else to choose between: carry on
			step_index += 1
			continue
		var flip: bool = (hash(str(world["tasks"][t].get("name", "")) + str(t)) & 1) == 1
		current_options = [alt, good] if flip else [good, alt]
		return

# An option: who, when and how for a task, started as soon as the people can be there unless a start is given. A skip leaves the task out.
func _option_for(t: int, party: int, performance: bool, start: int, skip: bool) -> Dictionary:
	if skip:
		return {"task": t, "skip": true, "party": 0, "start": 0, "performance": false}
	var saved: Dictionary = picks[t].duplicate()
	picks[t] = {"party": 0, "start": 0, "performance": false}
	for c in range(world["chars"].size()):
		if (party >> c) & 1 == 1:
			toggle_member(t, c)
	picks[t]["performance"] = performance and world["tasks"][t]["kind"] == "scout"
	picks[t]["start"] = earliest_start(t) # the soonest slot where nobody is double-booked and the place has room
	if start >= 0:
		picks[t]["start"] = start
	var option: Dictionary = {"task": t, "skip": false, "party": party, "start": int(picks[t]["start"]), "performance": bool(picks[t]["performance"]), "takes": duration(t)}
	picks[t] = saved
	return option

# The plan if this option is taken and every task after it is done the way the best plan does it: its score (-999999 when it does not work) and when it ends.
func _completion(t: int, option: Dictionary) -> Dictionary:
	var trial = get_script().new()
	trial.world = world
	trial.best_plan = best_plan
	trial.best_objective = best_objective
	trial.distances = distances
	trial.picks = picks.duplicate(true)
	trial.step_order = step_order
	trial._apply(t, option)
	for i in range(step_index + 1, step_order.size()):
		var u: int = step_order[i]
		trial._apply(u, trial._option_for(u, int(best_plan["party"][u]), best_plan["how"][u] == "PERFORMANCE", -1, false))
	var v: Dictionary = trial.verdict()
	return {"score": int(v["score"]) if v["allowed"] else -999999, "end": int(v.get("end", 0))}

func _completion_score(t: int, option: Dictionary) -> int:
	return int(_completion(t, option)["score"])

# The alternative that costs the least among those that cost enough to matter: a close call, but one that changes the score.
func _best_alternative(t: int, good_score: int) -> Dictionary:
	var task: Dictionary = world["tasks"][t]
	var good_party := int(best_plan["party"][t])
	var good_performance: bool = best_plan["how"][t] == "PERFORMANCE"
	var candidates: Array = []
	# swap a member for another of the same role, who can reach
	for c in range(world["chars"].size()):
		if (good_party >> c) & 1 == 0:
			continue
		for d in range(world["chars"].size()):
			if (good_party >> d) & 1 == 1 or world["chars"][d]["role"] != world["chars"][c]["role"] or int(world["chars"][d]["reach"]) < int(task["reach"]):
				continue
			var swapped: int = (good_party & ~(1 << c)) | (1 << d)
			var option := _option_for(t, swapped, good_performance, -1, false)
			option["why"] = "%s goes instead of %s" % [_name(d), _name(c)]
			option["kind"] = "who"
			option["swapped_in"] = d
			option["swapped_out"] = c
			candidates.append(option)
	var soonest := _option_for(t, good_party, good_performance, -1, false)
	# a scout the best plan performs, done quickly instead
	if task["kind"] == "scout" and good_performance:
		var quick := _option_for(t, good_party, false, -1, false)
		quick["why"] = "no performance, so no bonus"
		quick["kind"] = "perform"
		candidates.append(quick)
	# an optional task the best plan does, left out
	if not bool(task["required"]):
		var skipped := _option_for(t, 0, false, -1, true)
		skipped["why"] = "it is left out"
		skipped["kind"] = "skip"
		candidates.append(skipped)
	var chosen: Dictionary = {}
	var chosen_loss := 1 << 30
	candidate_losses = []
	for option in candidates:
		var score := _completion_score(t, option)
		var loss := good_score - score
		if score > -999999:
			candidate_losses.append(loss)
		if score > -999999 and loss >= MIN_COST and loss < chosen_loss:
			chosen = option
			chosen_loss = loss
	if not chosen.is_empty():
		chosen["loss"] = chosen_loss
	return chosen

func _name(c: int) -> String:
	return ["Father", "Mother", "Fritz", "Ernest", "Jack", "Francis"][c]

# ---- the evidence, on the same card as the question ----------------------------------------------------------------------------------------------------------------
# Facts only, none of them an answer: for the question on screen, what each family member is and when they are free, and what the chapter still asks of them.
#   {"members": [{"name", "role", "stride", "perform", "free_at"}, ...], "after": [{"name", "needs", "takes", "at", "required"}, ...]}
func evidence() -> Dictionary:
	if choices_done():
		return {}
	var members: Array = []
	for c in range(world["chars"].size()):
		var info: Dictionary = world["chars"][c]
		var free_at := 0
		for u in range(task_count()):
			if is_done(u) and (int(picks[u]["party"]) >> c) & 1 == 1:
				free_at = max(free_at, int(picks[u]["start"]) + duration(u))
		members.append({"name": _name(c), "role": str(info["role"]), "stride": int(info["stride"]), "perform": bool(info["perform"]), "free_at": free_at})
	var after: Array = []
	for i in range(step_index + 1, step_order.size()):
		var u: int = step_order[i]
		var task: Dictionary = world["tasks"][u]
		after.append({"name": _task_name(u), "task": u, "at": int(task["at"]), "required": bool(task["required"]), "kind": str(task["kind"]), "roles": task.get("roles", [0, 0, 0, 0]),
			"quick": int(task["quick"]), "perf": int(task["perf"])})
	return {"members": members, "after": after}

func _task_name(t: int) -> String:
	return str(world["tasks"][t].get("name", "")).split(":")[0]

func _worth_of(task: Dictionary, performed: bool) -> int:
	var v: int = int(world["point_weight"]) * int(task["points"])
	if task["kind"] == "duty" or performed:
		v += int(task["bonus"])
	return v

# A name cut to fit a line, at a word boundary.
func _short(text: String, length: int) -> String:
	if text.length() <= length:
		return text
	var cut := text.substr(0, length - 1)
	var space := cut.rfind(" ")
	return (cut.substr(0, space) if space > length / 2 else cut) + "…"
