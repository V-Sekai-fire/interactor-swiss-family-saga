# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The plan checker: the rules of the Party Saga model (entities/fixtures/minizinc/party-saga/party-saga.mzn, constraints 70 to 94) as code, so the page can tell
# whether a plan is allowed and what it scores. Every verdict is tested against the model itself (conformance/*.json, made by tools/conformance.exs).
# A world is a Dictionary as in the fixtures; a plan has "done", "party" (a bit mask of characters per task), "how", "arm" and "start".
class_name Checker

const INF := 1000000

# Time one character needs over one edge: the quickest of its modes (mode_time in the model).
static func mode_time(world: Dictionary, c: Dictionary, edge: Array, mode: String) -> int:
	if not c["modes"].has(mode):
		return INF
	var length: int = edge[2]
	var terrain: String = edge[3]
	var stride: int = c["stride"]
	var speed := 0
	var ramp := 0
	if mode == "STICK":
		speed = stride if terrain == "land" else (stride / 2 if terrain == "water" else 0)
		ramp = 1
	elif mode == "SPRINT":
		speed = (stride * 3) / 2 if terrain == "land" else 0
		ramp = 2
	elif mode == "CLIMB":
		ramp = 1
	elif mode == "TELEPORT":
		return 1 if length <= int(world["blink_range"]) else INF
	if speed <= 0:
		return INF
	return (length * 100 + speed - 1) / speed + ramp

# Shortest travel times between all places for one character (Floyd-Warshall, as fw in the model); row u, column v.
static func distances(world: Dictionary, c: Dictionary) -> Array:
	var n: int = world["nodes"]
	var d: Array = []
	for u in range(n):
		var row: Array = []
		for v in range(n):
			row.append(0 if u == v else INF)
		d.append(row)
	for edge in world["edges"]:
		var best := INF
		for mode in ["STICK", "SPRINT", "CLIMB", "TELEPORT"]:
			best = min(best, mode_time(world, c, edge, mode))
		var u: int = int(edge[0]) - 1
		var v: int = int(edge[1]) - 1
		d[u][v] = min(d[u][v], best)
	for k in range(n):
		for u in range(n):
			for v in range(n):
				if d[u][k] + d[k][v] < d[u][v]:
					d[u][v] = d[u][k] + d[k][v]
	return d

static func in_party(plan: Dictionary, c: int, t: int) -> bool:
	return (int(plan["party"][t]) >> c) & 1 == 1

static func duration(world: Dictionary, plan: Dictionary, t: int) -> int:
	var task: Dictionary = world["tasks"][t]
	if task["kind"] == "duty" or plan["how"][t] == "QUICK":
		return task["quick"]
	return task["perf"]

# The arms a task keeps busy in its zone (usage in the model).
static func usage(world: Dictionary, plan: Dictionary, t: int) -> int:
	var task: Dictionary = world["tasks"][t]
	if task["kind"] == "duty":
		var members := 0
		for c in range(world["chars"].size()):
			if in_party(plan, c, t):
				members += 1
		return 2 * members
	return 2 if plan["how"][t] == "PERFORMANCE" else 1

# Returns {"allowed": bool, "reason": String, "objective": int, "end": int}. The reason names the first rule a plan breaks.
static func check(world: Dictionary, plan: Dictionary) -> Dictionary:
	var chars: Array = world["chars"]
	var tasks: Array = world["tasks"]
	var nc := chars.size()
	var nt := tasks.size()
	var dist: Array = []
	for c in chars:
		dist.append(distances(world, c))
	# a task that is not done has no party, starts at 0 and is quick
	for t in range(nt):
		var task: Dictionary = tasks[t]
		if task["required"] and not plan["done"][t]:
			return _no("a required task is not done", t)
		if not plan["done"][t]:
			if int(plan["start"][t]) != 0 or plan["how"][t] != "QUICK" or int(plan["party"][t]) != 0:
				return _no("a task that is not done must start at 0, quick, with no party", t)
	for t in range(nt):
		if not plan["done"][t]:
			continue
		var task: Dictionary = tasks[t]
		var members := 0
		for c in range(nc):
			if in_party(plan, c, t):
				members += 1
		if task["kind"] == "scout":
			if members != 1:
				return _no("a scout is done by exactly one character", t)
			if (plan["how"][t] == "PERFORMANCE") != (plan["arm"][t] == "BOTH"):
				return _no("a performance uses both arms and only a performance does", t)
		else:
			if plan["how"][t] != "QUICK" or plan["arm"][t] != "BOTH":
				return _no("a duty is quick and uses both arms", t)
			for r in range(4):
				var count := 0
				for c in range(nc):
					if in_party(plan, c, t) and _role_index(chars[c]["role"]) == r:
						count += 1
				if count != int(task["roles"][r]):
					return _no("a duty needs exactly its role mix", t)
		var dur := duration(world, plan, t)
		for c in range(nc):
			if not in_party(plan, c, t):
				continue
			var d: int = dist[c][int(chars[c]["home"]) - 1][int(task["at"]) - 1]
			if d >= INF or int(plan["start"][t]) < d:
				return _no("a character cannot reach the place in time", t)
			if int(task["reach"]) > int(chars[c]["reach"]):
				return _no("the character's arm does not reach", t)
			if task["kind"] == "scout" and plan["how"][t] == "PERFORMANCE" and not chars[c]["perform"]:
				return _no("this character cannot perform", t)
			if int(plan["start"][t]) < int(task["release"]) or int(plan["start"][t]) + dur > int(task["deadline"]):
				return _no("the task is outside its time window", t)
	# one character does one thing at a time, with travel and the duty cooldown between; two quick scouts at one place may share, one arm each
	for c in range(nc):
		for t1 in range(nt):
			for t2 in range(t1 + 1, nt):
				if not (plan["done"][t1] and plan["done"][t2] and in_party(plan, c, t1) and in_party(plan, c, t2)):
					continue
				var duty_gap: int = int(chars[c]["cooldown"]) if tasks[t1]["kind"] == "duty" and tasks[t2]["kind"] == "duty" else 0
				var a: int = int(tasks[t1]["at"]) - 1
				var b: int = int(tasks[t2]["at"]) - 1
				var first: bool = int(plan["start"][t2]) >= int(plan["start"][t1]) + duration(world, plan, t1) + dist[c][a][b] + duty_gap
				var second: bool = int(plan["start"][t1]) >= int(plan["start"][t2]) + duration(world, plan, t2) + dist[c][b][a] + duty_gap
				var shared: bool = tasks[t1]["kind"] == "scout" and tasks[t2]["kind"] == "scout" and a == b \
					and plan["how"][t1] == "QUICK" and plan["how"][t2] == "QUICK" and plan["arm"][t1] != plan["arm"][t2]
				if not (first or second or shared):
					return _no("a character is in two tasks at once", t1)
	# a zone holds a number of arms at once (cumulative)
	for z in range(world["zones"].size()):
		var cut_points: Array = []
		for t in range(nt):
			if plan["done"][t] and int(tasks[t]["zone"]) == z + 1:
				cut_points.append(int(plan["start"][t]))
		for moment in cut_points:
			var zone_arms := 0
			for t in range(nt):
				if plan["done"][t] and int(tasks[t]["zone"]) == z + 1 and int(plan["start"][t]) <= moment and moment < int(plan["start"][t]) + duration(world, plan, t):
					zone_arms += usage(world, plan, t)
			if zone_arms > int(world["zones"][z]):
				return _no("too many arms work in one zone", -1)
	# rank gates and the order of tasks
	for t in range(nt):
		if not plan["done"][t]:
			continue
		if int(tasks[t]["min_points"]) > 0:
			var earned := 0
			for u in range(nt):
				if u != t and plan["done"][u] and int(plan["start"][u]) + duration(world, plan, u) <= int(plan["start"][t]):
					earned += int(tasks[u]["points"])
			if earned < int(tasks[t]["min_points"]):
				return _no("the rank gate is not reached", t)
	for pair in world["pairs"]:
		var before: int = int(pair[0]) - 1
		var after: int = int(pair[1]) - 1
		if plan["done"][after]:
			if not plan["done"][before]:
				return _no("a task needs another task to be done first", after)
			if int(plan["start"][after]) < int(plan["start"][before]) + duration(world, plan, before):
				return _no("a task starts before the one it needs is finished", after)
	# art crystals are not part of the story's worlds: a world with crystals is refused rather than guessed
	if world["crystals"].size() > 0:
		return _no("crystals are not supported by the checker", -1)
	var end := 0
	var points := 0
	var bonus := 0
	for t in range(nt):
		if plan["done"][t]:
			end = max(end, int(plan["start"][t]) + duration(world, plan, t))
			points += int(tasks[t]["points"])
			if tasks[t]["kind"] == "duty" or plan["how"][t] == "PERFORMANCE":
				bonus += int(tasks[t]["bonus"])
	return {"allowed": true, "reason": "", "end": end, "objective": int(world["time_weight"]) * end - bonus - int(world["point_weight"]) * points}

static func _role_index(role: String) -> int:
	return ["tank", "healer", "damage", "support"].find(role)

static func _no(reason: String, task: int) -> Dictionary:
	return {"allowed": false, "reason": reason, "task": task}
