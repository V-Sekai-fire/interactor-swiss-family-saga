# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# docs/code.md
extends SceneTree

const State := preload("res://game/scripts/game_state.gd")
const Main := preload("res://game/scripts/main.gd")
var failures := 0

func _check(name: String, ok: bool) -> void:
	if not ok:
		failures += 1
		print("FAIL ", name)

func _init() -> void:
	for chapter in ["ch01_landing", "ch02_falconhurst", "ch03_boat", "ch04_rockburg", "ch05_stairs", "ch06_farms", "ch07_cape", "ch08_ship"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://conformance/%s.json" % chapter))
		var roles: Array = data["world"]["chars"].map(func(ch): return str(ch["role"]))
		_check("%s: the screen's roles are the chapter's" % chapter, roles == Main.FAMILY_ROLE)
		for policy in ["best", "other", "first"]:
			var s = State.new()
			s.load_chapter(data)
			s.begin_choices()
			var steps := 0
			var two_each := true
			var cost := 0
			while not s.choices_done():
				var step: Dictionary = s.current_step()
				if step["options"].size() != 2:
					two_each = false
				var wrong := 0
				for o in step["options"]:
					wrong = max(wrong, int(o["loss"]))
				_check("%s/%s: a decision costs at least %d" % [chapter, policy, State.MIN_COST], wrong >= State.MIN_COST)
				var k := 0
				for i in range(2):
					var loss: int = int(step["options"][i]["loss"])
					if policy == "best" and loss == 0:
						k = i
					elif policy == "other" and loss > 0:
						k = i
					elif policy == "first":
						k = 0
				cost += int(s.choose(k)["loss"])
				steps += 1
			var v: Dictionary = s.verdict()
			_check("%s/%s: every step offers two options" % [chapter, policy], two_each)
			_check("%s/%s: the chapter has at least two decisions (%d)" % [chapter, policy, steps], steps >= 2)
			_check("%s/%s: the finished plan works" % [chapter, policy], v["allowed"])
			if policy == "best":
				_check("%s/best: the best options reach the best plan" % chapter, v["allowed"] and v["score"] == s.best_score())
			elif v["allowed"]:
				_check("%s/%s: other options never beat the best" % [chapter, policy], v["score"] <= s.best_score())
			print("%s/%s: %d decisions, score %s of %d, cost %d" % [chapter, policy, steps, str(v.get("score", "refused")), s.best_score(), cost])
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
