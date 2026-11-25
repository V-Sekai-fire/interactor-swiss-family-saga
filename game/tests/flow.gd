# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The screen's flow: Next stays locked until the chapter is done, the tasks are listed with the required ones first, and the console speaks.
# Run: godot --headless --path . --script game/tests/flow.gd
extends SceneTree

const MainScene := preload("res://game/scenes/main.tscn")
var failures := 0

func _check(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", what)

func _has_letters(text: String) -> bool:
	for i in range(text.length()):
		if text[i].to_lower() != text[i].to_upper():
			return true
	return false

func _initialize() -> void:
	root.size = Vector2i(1180, 780)
	var scene: Control = MainScene.instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for chapter in range(8):
		scene.chapter = chapter
		scene._open_chapter()
		await process_frame
		_check(scene.next_button.disabled, "chapter %d: Next is locked at the start" % (chapter + 1))
		var before: int = scene.chapter
		scene._go(1)
		_check(scene.chapter == before, "chapter %d: going on is refused before the chapter is done" % (chapter + 1))
		_check(scene.console_lines.size() >= 1, "chapter %d: the console says something" % (chapter + 1))
		var seen_optional := false
		for t in scene.row_task:
			var required: bool = bool(scene.state.world["tasks"][t]["required"])
			if not required:
				seen_optional = true
			_check(required or seen_optional, "chapter %d: required tasks come first" % (chapter + 1))
			_check(not (required and seen_optional), "chapter %d: no required task after an optional one" % (chapter + 1))
		_check(scene.row_task.size() == scene.state.task_count(), "chapter %d: every task has a row" % (chapter + 1))
		while not scene.state.choices_done():
			scene._choose(0)
			await process_frame
		_check(scene.next_button.disabled == (chapter == 7), "chapter %d: Next opens when every decision is made, except on the last chapter" % (chapter + 1))
	scene.chapter = 0
	scene._open_chapter()
	await process_frame
	scene._go(1)
	_check(scene.chapter == 0, "still on chapter 1 after a refused Next")
	# Restart from the middle of a run and from the editor returns to the first decision with Next locked
	scene._choose(0)
	scene._choose(0)
	scene._toggle_edit()
	scene._restart()
	await process_frame
	_check(not scene.edit_card.visible and scene.choice_card.visible, "Restart closes the editor and shows the decisions")
	_check(scene.state.current_step()["index"] == 0, "Restart goes back to the first decision")
	_check(scene.next_button.disabled, "Restart locks Next again")
	_check(scene.console_lines.size() == 1, "Restart clears the console")
	# The chapters are a line: Previous on the first and Next on the last do nothing and are disabled
	scene.chapter = 0
	scene._open_chapter()
	await process_frame
	_check(scene.previous_button.disabled, "Previous is disabled on the first chapter")
	scene._go(-1)
	_check(scene.chapter == 0, "Previous on the first chapter stays on it")
	scene.chapter = 7
	scene._open_chapter()
	while not scene.state.choices_done():
		scene._choose(0)
	await process_frame
	_check(scene.next_button.disabled and not scene.previous_button.disabled, "Next is disabled on the last chapter even when it is done")
	scene._go(1)
	_check(scene.chapter == 7, "Next on the last chapter stays on it")
	# The evidence is on the card from the first question and Solve (a toggle, off at the start) rings the better answer on every question until turned off
	scene.chapter = 0
	scene._open_chapter()
	await process_frame
	var none := func(): return not scene.option_buttons[0].button_pressed and not scene.option_buttons[1].button_pressed
	_check(scene.evidence_label.visible and scene.evidence_label.text.contains("THE FAMILY") and scene.evidence_label.text.contains("YOUR RECORD"), "the evidence is on the card at the start")
	_check(not scene.solve_button.button_pressed and none.call(), "Solve is off and no answer is ringed at the start")
	scene.solve_button.button_pressed = true
	scene._solve()
	await process_frame
	var better: int = scene._better_answer()
	_check(scene.option_buttons[better].button_pressed and not scene.option_buttons[1 - better].button_pressed, "Solve: the better answer is ringed")
	scene._choose(better)
	await process_frame
	_check(scene.option_buttons[scene._better_answer()].button_pressed, "Solve stays on for the next question")
	_check(scene.record["who"][0] + scene.record["perform"][0] + scene.record["skip"][0] == 1, "a right answer counts once in the record")
	_check(scene.evidence_label.text.contains("1/1"), "the record line shows it")
	scene.solve_button.button_pressed = false
	scene._solve()
	await process_frame
	_check(none.call(), "Solve off again: nothing is ringed")
	print("RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
