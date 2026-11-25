# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# Prints every decision's clue for review and checks that each clue exists and is not empty. Run: godot --headless --path . --script game/tests/clues.gd
extends SceneTree

const State := preload("res://game/scripts/game_state.gd")

func _init() -> void:
	var failures := 0
	for chapter in ["ch01_landing", "ch02_falconhurst", "ch03_boat", "ch04_rockburg", "ch05_stairs", "ch06_farms", "ch07_cape", "ch08_ship"]:
		var data = JSON.parse_string(FileAccess.get_file_as_string("res://conformance/%s.json" % chapter))
		var s = State.new()
		s.load_chapter(data)
		s.begin_choices()
		while not s.choices_done():
			var step: Dictionary = s.current_step()
			var text: String = s.clue()
			if text == "":
				failures += 1
				print("FAIL empty clue ", chapter)
			print("CLUE %s %s: %s" % [chapter.substr(0, 4), step["kind"], text])
			# the clue must point to the better answer: for who-questions, check the rule it states against the model's own best option
			s.choose(0 if int(step["options"][0]["loss"]) == 0 else 1)
	print("RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
