# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Plays every chapter through the game state, the way the screen does, and checks the rules of play. Run: godot --headless --path . --script game/tests/gameplay.gd
extends SceneTree

const State := preload("res://game/scripts/game_state.gd")
var failures := 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		failures += 1
		print("FAIL ", name)

func _init() -> void:
	for chapter in ["ch01_landing", "ch02_falconhurst", "ch03_boat", "ch04_rockburg", "ch05_stairs", "ch06_farms", "ch07_cape", "ch08_ship"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://conformance/%s.json" % chapter))
		var s = State.new()
		s.load_chapter(data)
		# nothing done: refused, because a required task is not done
		var v: Dictionary = s.verdict()
		_check(chapter + ": an empty plan is refused", not v["allowed"] and v["reason"] == "a required task is not done")
		# the model's best plan, loaded as picks, is allowed and scores the best
		s.load_best()
		v = s.verdict()
		_check(chapter + ": the best plan is allowed", v["allowed"])
		_check(chapter + ": the best plan scores the best", v["allowed"] and v["score"] == s.best_score())
		# the plan the screen builds is the plan the model gave
		var p: Dictionary = s.plan()
		var b: Dictionary = s.best_plan
		var same := true
		for t in range(s.task_count()):
			if bool(p["done"][t]) != bool(b["done"][t]) or int(p["party"][t]) != int(b["party"][t]) or (bool(b["done"][t]) and int(p["start"][t]) != int(b["start"][t])):
				same = false
		_check(chapter + ": picks rebuild the model's plan", same)
		# taking someone off a required task makes it refused
		var dropped := -1
		for t in range(s.task_count()):
			if s.is_done(t) and bool(s.world["tasks"][t]["required"]):
				dropped = t
				break
		s.clear_task(dropped)
		_check(chapter + ": a required task cleared is refused", not s.verdict()["allowed"])
		# playing it by hand: put members on every task in turn; the start is chosen for the player
		s.clear_all()
		for t in range(s.task_count()):
			if not bool(s.world["tasks"][t]["required"]):
				continue
			for c in range(s.world["chars"].size()):
				if (int(s.best_plan["party"][t]) >> c) & 1 == 1:
					s.toggle_member(t, c)
		v = s.verdict()
		# an honest hand-built plan of the required tasks is either allowed or names a rule; if allowed it may not beat the best
		_check(chapter + ": a hand-built plan never beats the model", not v["allowed"] or v["score"] <= s.best_score())
		if v["allowed"]:
			var r: Dictionary = s.regret()
			var total: int = int(r["time_cost"])
			for entry in r["losses"]:
				total += int(entry["loss"])
			_check(chapter + ": the regret adds up to the gap to the best (%d vs %d)" % [total, int(r["gap"])], total == int(r["gap"]))
		# the hint, asked again and again, walks the player to the best plan
		s.clear_all()
		var hints := 0
		while not s.hint().is_empty() and hints < 20:
			hints += 1
		v = s.verdict()
		_check(chapter + ": hints lead to the best plan (%d hints)" % hints, v["allowed"] and v["score"] == s.best_score() and s.stars() == 3)
		# tidying the best plan keeps it the best; tidying a slack plan never makes it worse
		s.load_best()
		s.tidy()
		_check(chapter + ": tidying the best plan keeps its score", s.verdict()["allowed"] and s.verdict()["score"] == s.best_score())
		# "Earliest" never lands later than a start the best plan already has, and moving a task there leaves the plan working
		s.load_best()
		var earliest_ok := true
		for t in range(s.task_count()):
			if not s.is_done(t):
				continue
			s.load_best()
			var was: int = int(s.picks[t]["start"])
			if s.earliest_start(t) > was:
				earliest_ok = false
			s.start_earliest(t)
			if not s.verdict()["allowed"]:
				earliest_ok = false
		_check(chapter + ": Earliest is never later than the best plan and keeps it working", earliest_ok)
		print("%s: hand-built plan %s%s" % [chapter, "allowed, score %d of %d" % [v["score"], s.best_score()] if v["allowed"] else "refused: ", "" if v["allowed"] else v["reason"]])
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
