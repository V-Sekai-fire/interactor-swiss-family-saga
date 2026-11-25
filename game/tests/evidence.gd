# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The evidence on the question card: facts the player can solve the screen from, and none of them an answer. Run: godot --headless --path . --script game/tests/evidence.gd
extends SceneTree

const GameState := preload("res://game/scripts/game_state.gd")
const CHAPTERS := ["ch01_landing", "ch02_falconhurst", "ch03_boat", "ch04_rockburg", "ch05_stairs", "ch06_farms", "ch07_cape", "ch08_ship"]
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)

func _initialize() -> void:
	var checked := 0
	for file in CHAPTERS:
		var state := GameState.new()
		state.load_chapter(JSON.parse_string(FileAccess.get_file_as_string("res://conformance/%s.json" % file)))
		state.begin_choices()
		var guard := 0
		while not state.choices_done() and guard < 40:
			guard += 1
			var evidence: Dictionary = state.evidence()
			var step: Dictionary = state.current_step()
			var tag := "%s question %d" % [file, int(step["index"]) + 1]
			_check(evidence["members"].size() == state.world["chars"].size(), tag + ": every member of the family is listed")
			# the facts are the world's own: role and stride from the data, free_at from what is already placed
			for c in range(evidence["members"].size()):
				var member: Dictionary = evidence["members"][c]
				var free_at := 0
				for u in range(state.task_count()):
					if state.is_done(u) and (int(state.picks[u]["party"]) >> c) & 1 == 1:
						free_at = max(free_at, int(state.picks[u]["start"]) + state.duration(u))
				_check(int(member["free_at"]) == free_at, tag + ": %s is free at %d" % [member["name"], free_at])
				_check(str(member["role"]) == str(state.world["chars"][c]["role"]) and int(member["stride"]) == int(state.world["chars"][c]["stride"]), tag + ": %s role and stride are the world's" % member["name"])
			# what is still to do is exactly the questions after this one, never this one
			_check(evidence["after"].size() == state.step_order.size() - state.step_index - 1, tag + ": the rest of the chapter is listed")
			for task in evidence["after"]:
				_check(int(task["task"]) != int(step["task"]), tag + ": this question's task is not in the rest")
			# no answer: nothing in the evidence says which option is better
			for member in evidence["members"]:
				_check(not member.has("loss") and not member.has("better"), tag + ": a member row carries no verdict")
			_check(not evidence.has("answer") and not evidence.has("best"), tag + ": the evidence carries no answer")
			checked += 1
			state.choose(0)
		_check(state.evidence().is_empty(), file + ": no evidence once every question is answered")
	_check(checked > 0, "some questions were checked")
	# a choice changes the evidence: the members sent are busy afterwards
	var one := GameState.new()
	one.load_chapter(JSON.parse_string(FileAccess.get_file_as_string("res://conformance/ch01_landing.json")))
	one.begin_choices()
	var before: Dictionary = one.evidence()
	one.choose(0)
	var after: Dictionary = one.evidence()
	var busier := 0
	for c in range(before["members"].size()):
		if int(after["members"][c]["free_at"]) > int(before["members"][c]["free_at"]):
			busier += 1
	_check(busier > 0, "answering a question makes someone busier in the evidence")
	print("RESULT: %d failures (%d questions)" % [failures, checked])
	quit(1 if failures > 0 else 0)
