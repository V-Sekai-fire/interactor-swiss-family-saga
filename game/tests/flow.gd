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
		_check(not scene.next_button.disabled, "chapter %d: Next opens when every decision is made" % (chapter + 1))
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
	# Two levels of help, both off at the start: Hint (one-shot) makes this question's clue readable, Solve (a toggle) rings the better answer on every question until turned off
	scene.chapter = 0
	scene._open_chapter()
	await process_frame
	var none := func(): return not scene.option_buttons[0].button_pressed and not scene.option_buttons[1].button_pressed
	_check(not scene.hint_button.button_pressed and not scene.solve_button.button_pressed, "both help levels are off at the start")
	_check(scene.clue_label.visible and not _has_letters(scene.clue_label.text.substr(2)), "the clue is there but unreadable at the start")
	_check(none.call(), "no answer is ringed at the start")
	scene.hint_button.pressed.emit()
	await process_frame
	_check(_has_letters(scene.clue_label.text) and none.call(), "Hint: the clue is readable and no answer is ringed")
	_check(not scene.hint_button.toggle_mode, "Hint is a one-shot button, not a toggle")
	scene.solve_button.button_pressed = true
	scene._solve()
	await process_frame
	var better: int = scene._better_answer()
	_check(scene.option_buttons[better].button_pressed and not scene.option_buttons[1 - better].button_pressed, "Solve: the better answer is ringed")
	scene._choose(better)
	await process_frame
	_check(not _has_letters(scene.clue_label.text.substr(2)) and scene.option_buttons[scene._better_answer()].button_pressed, "the next question masks the clue again; Solve stays on")
	scene.solve_button.button_pressed = false
	scene._solve()
	await process_frame
	_check(not _has_letters(scene.clue_label.text.substr(2)) and none.call(), "Solve off again: nothing is ringed and the clue is still unreadable")
	print("RESULT: %d failures" % failures)
	quit(1 if failures > 0 else 0)
