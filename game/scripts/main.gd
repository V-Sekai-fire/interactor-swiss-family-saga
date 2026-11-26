# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The game screen, in the Chibifire design system: the chapter and its island, the tasks it asks for, the family, and the plan the player builds. Any plan may be
# built; the checker judges it as it changes, and the score is set against the model's best.
extends Control

const Look = preload("res://look/look.gd")
const CheckerScript := preload("res://game/scripts/checker.gd")
const IslandMap := preload("res://game/scripts/island_map.gd")
const State := preload("res://game/scripts/game_state.gd")
const Timeline := preload("res://game/scripts/timeline.gd")
const CHAPTERS := [
	["ch01_landing", "The landing"], ["ch02_falconhurst", "Falconhurst"], ["ch03_boat", "The tub boat"], ["ch04_rockburg", "Rockburg"],
	["ch05_stairs", "Stairs and the bridge"], ["ch06_farms", "Farms and the pinnace"], ["ch07_cape", "Cape Minster"], ["ch08_ship", "The ship"],
]
const FAMILY := ["Father", "Mother", "Fritz", "Ernest", "Jack", "Francis"]
# Each role has one emoji, shown after the name and in what a task needs, so matching people to a task is reading, not remembering. Per role, not per person:
# a task asks for "a damage", and Ernest or Jack fills it. The roles are levels/family.exs's; game/tests/choices.gd checks every chapter agrees.
const ROLE_EMOJI := {"tank": "💪", "healer": "🩹", "damage": "🎯", "support": "🤝"}
const FAMILY_ROLE := ["support", "healer", "tank", "damage", "damage", "support"]
const PREMISES := [
	"The wreck lies off Safety Bay. Bring the stores ashore, set up the first camp and find fresh water before night.",
	"The great tree at the river is the safe house. Fell the timber, raise a platform, bridge the river.",
	"The wreck still holds timber and tools. Join cut tubs into a boat and cross to Shark Island and back.",
	"The rains are coming and the tree house will not hold. Hew a cave into the rock at Rockburg.",
	"The ladder is not safe for the mother and Francis. Cut a stair into the trunk, bridge the creek.",
	"Plant the fields, fence the animals and rebuild the pinnace so the family can sail round the island.",
	"With the pinnace the far shore is in reach. Scout the cape and light a signal fire ships can see.",
	"Years have passed and a sail is on the horizon. Light the fire, bring the journal, receive the captain.",
]
# The design system's four state colours, one per role.
const ROLE_COLOURS := {"tank": "bad", "healer": "good", "damage": "warn", "support": "note"}

var chapter := 0
var state: RefCounted = State.new()
var selected := 0
var kicker: Label
var map: Control
var timeline: Control
var premise: Label
var verdict: Label
var console: Label
var console_lines: Array = []
var next_button: Button
var previous_button: Button
var row_task: Array = []
var choice_kicker: Label
var choice_prompt: Label
var rule: Label
var clue_label: Label
var option_buttons: Array = []
var edit_card: Control
var choice_card: Control
var note := ""
var dot: ColorRect
var task_rows: Array = []        # per task: {"row", "button", "who"}
var detail: Label
var member_buttons: Array = []
var start_label: Label
var earliest_label: Label
var perform_button: Button
var island_edges: Array = []
var hinted := -1
var hints_on := false
var solve_on := false
var hint_button: Button
var solve_button: Button
var clue_text := ""

func _ready() -> void:
	Look.fit(get_window())
	var theme: Theme = Look.make()
	get_window().theme = theme
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Look.sky(self)
	var page := Look.page(self)

	var top := HBoxContainer.new()
	page.add_child(top)
	var title := Label.new()
	title.text = "The Swiss Family Saga"
	Look.heading(title, Look.T.FONT_SIZE_PANEL_HEADING)
	top.add_child(title)
	kicker = Look.kicker_end("")
	top.add_child(kicker)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", Look.GAP)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_child(body)

	# left: the island, and the plan as a timeline
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", Look.GAP)
	left.custom_minimum_size = Vector2(540, 0)
	body.add_child(left)
	var island := Look.card(left, "The island", "", 1)
	premise = Label.new()
	Look.muted(premise, 13)
	premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	premise.custom_minimum_size = Vector2(500, 0)
	island.add_child(premise)
	map = IslandMap.new()
	map.custom_minimum_size = Vector2(500, 168)
	island.add_child(map)
	var plan_box := Look.card(left, "The plan", "", 1)
	timeline = Timeline.new()
	timeline.custom_minimum_size = Vector2(500, 6 * 22 + 20)
	timeline.state = state
	timeline.names = range(FAMILY.size()).map(func(c): return _who(c))
	plan_box.add_child(timeline)
	console = Label.new()
	Look.muted(console, 12)
	console.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	console.custom_minimum_size = Vector2(500, 78)
	console.clip_text = true
	console.max_lines_visible = 4
	plan_box.add_child(console)

	# right: the tasks, and the one being planned
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", Look.GAP)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var tasks_box := Look.card(right, "What must be done", "", 1)
	for t in range(6):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		tasks_box.add_child(row)
		var pick := Button.new()
		pick.toggle_mode = true
		_style_row(pick)
		Look.row_button(pick)
		pick.pressed.connect(_select_row.bind(t))
		row.add_child(pick)
		var who := Label.new()
		Look.muted(who, 12)
		Look.fixed(who, 1, 150)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(who)
		task_rows.append({"row": row, "button": pick, "who": who})

	var choice := Look.card(right, "Your choice", "", 1)
	choice_card = choice.get_parent()
	choice_kicker = Look.kicker("")
	choice.add_child(choice_kicker)
	choice_prompt = Label.new()
	Look.muted(choice_prompt, 13)
	choice_prompt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_prompt.custom_minimum_size = Vector2(520, 0)
	choice.add_child(choice_prompt)
	clue_label = Label.new()
	Look.muted(clue_label, 12)
	clue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	clue_label.custom_minimum_size = Vector2(520, 0)
	clue_label.add_theme_color_override("font_color", Look.c("lit"))
	choice.add_child(clue_label)
	for k in range(2):
		var option := Button.new()
		option.custom_minimum_size = Vector2(500, 52)
		option.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		option.alignment = HORIZONTAL_ALIGNMENT_LEFT
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_toggle(option)
		option.toggle_mode = true
		option.pressed.connect(_choose.bind(k))
		choice.add_child(option)
		option_buttons.append(option)

	rule = Label.new()
	Look.muted(rule, Look.T.FONT_SIZE_HINT)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size = Vector2(520, 0)
	choice.add_child(rule)

	var editor := Look.card(right, "Who does it, and when", "", 1)
	edit_card = editor.get_parent()
	edit_card.visible = false
	detail = Label.new()
	Look.muted(detail, 12)
	Look.fixed(detail, 2, 520)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	editor.add_child(detail)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	editor.add_child(grid)
	for c in range(FAMILY.size()):
		var member := Button.new()
		member.toggle_mode = true
		member.text = _who(c)
		member.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_style_toggle(member)
		member.pressed.connect(_member.bind(c))
		grid.add_child(member)
		member_buttons.append(member)
	var timing := HBoxContainer.new()
	timing.add_theme_constant_override("separation", 8)
	editor.add_child(timing)
	var start_title := Label.new()
	start_title.text = "Start"
	Look.muted(start_title, 13)
	timing.add_child(start_title)
	var earlier := Button.new()
	earlier.text = "-"
	earlier.pressed.connect(_nudge.bind(-1))
	timing.add_child(earlier)
	start_label = Label.new()
	Look.fixed(start_label, 1, 36)
	start_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing.add_child(start_label)
	var later := Button.new()
	later.text = "+"
	later.pressed.connect(_nudge.bind(1))
	timing.add_child(later)
	var soonest := Button.new()
	soonest.text = "Earliest"
	soonest.pressed.connect(_soonest)
	timing.add_child(soonest)
	earliest_label = Label.new()
	Look.muted(earliest_label, 12)
	earliest_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	timing.add_child(earliest_label)
	perform_button = Button.new()
	perform_button.toggle_mode = true
	perform_button.text = "Perform it"
	_style_toggle(perform_button)
	perform_button.pressed.connect(_perform)
	timing.add_child(perform_button)

	var aids := HBoxContainer.new()
	aids.add_theme_constant_override("separation", 8)
	editor.add_child(aids)
	for entry in [["Tidy up", _tidy], ["Clear", _clear], ["Best plan", _best]]:
		var aid := Button.new()
		aid.text = entry[0]
		aid.pressed.connect(entry[1])
		aids.add_child(aid)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", Look.GAP)
	page.add_child(bar)
	dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(dot)
	verdict = Label.new()
	Look.muted(verdict, 13)
	verdict.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	verdict.clip_text = true
	bar.add_child(verdict)
	for entry in [["Hint", _hint], ["Solve", _solve], ["Edit by hand", _toggle_edit], ["Restart", _restart], ["Previous", _go.bind(-1)], ["Next", _go.bind(1)]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		bar.add_child(button)
		if entry[0] == "Next":
			next_button = button
		if entry[0] == "Previous":
			previous_button = button
		if entry[0] == "Hint":
			hint_button = button
		if entry[0] == "Solve":
			button.toggle_mode = true
			_style_toggle(button)
			solve_button = button
	_open_chapter()

# A toggle that shows its state: outlined when off, inked when on (the design system's colours).
func _style_toggle(b: Button) -> void:
	b.add_theme_stylebox_override("normal", Look.box(Look.c("card"), 8, Look.c("line"), 8))
	b.add_theme_stylebox_override("hover", Look.box(Look.c("paper-2"), 8, Look.c("ink"), 8))
	b.add_theme_stylebox_override("pressed", Look.box(Look.c("ink"), 8, Look.c("ink"), 8))
	b.add_theme_stylebox_override("hover_pressed", Look.box(Look.c("ink"), 8, Look.c("lit"), 8))
	b.add_theme_stylebox_override("disabled", Look.box(Look.c("paper"), 8, Color(Look.c("line"), 0.5), 8))
	for colour_name in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(colour_name, Look.c("ink"))
	b.add_theme_color_override("font_pressed_color", Look.c("paper"))
	b.add_theme_color_override("font_hover_pressed_color", Look.c("paper"))
	b.add_theme_color_override("font_disabled_color", Color(Look.c("mute"), 0.6))

# A row of the task list: bare when it is not the one being planned, ringed when it is.
func _style_row(b: Button) -> void:
	var bare := Look.box(Color(0, 0, 0, 0), 8, Color(0, 0, 0, 0), 2)
	b.add_theme_stylebox_override("normal", bare)
	b.add_theme_stylebox_override("hover", Look.box(Color(Look.c("paper"), 0.6), 8, Color(0, 0, 0, 0), 2))
	b.add_theme_stylebox_override("pressed", Look.box(Look.c("paper"), 8, Look.c("ink"), 2))
	b.add_theme_stylebox_override("hover_pressed", Look.box(Look.c("paper"), 8, Look.c("ink"), 2))
	for colour_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(colour_name, Look.c("ink"))

func _load(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://conformance/%s.json" % file))

func _open_chapter() -> void:
	state.load_chapter(_load(CHAPTERS[chapter][0]))
	if island_edges.is_empty():
		island_edges = _load("ch07_cape")["world"]["edges"]
	state.begin_choices()
	note = ""
	row_task = []
	for t in range(state.task_count()):
		if bool(state.world["tasks"][t]["required"]):
			row_task.append(t)
	for t in range(state.task_count()):
		if not bool(state.world["tasks"][t]["required"]):
			row_task.append(t)
	console_lines = []
	_say("Chapter %d, %s: %d tasks, %d of them must be done." % [chapter + 1, CHAPTERS[chapter][1], state.task_count(), state.required_total()])
	selected = 0
	kicker.text = "CHAPTER %d OF %d · %s" % [chapter + 1, CHAPTERS.size(), str(CHAPTERS[chapter][1]).to_upper()]
	premise.text = PREMISES[chapter]
	map.set_world(state.world, island_edges)
	for t in range(task_rows.size()):
		task_rows[t]["row"].visible = t < state.task_count()
	_show_step()
	_refresh()

# A chapter is done when every decision is made, or when a plan built by hand works.
func _chapter_done() -> bool:
	return state.choices_done() or (edit_card.visible and bool(state.verdict()["allowed"]))

# The chapters are a line, not a ring: there is nothing before the first or after the last.
func _go(step: int) -> void:
	var target := chapter + step
	if target < 0 or target >= CHAPTERS.size():
		return
	if step > 0 and not _chapter_done():
		_say("Finish this chapter before going on.")
		_refresh()
		return
	chapter = target
	_open_chapter()

func _select_row(r: int) -> void:
	_select(row_task[r])

# The console: what has happened, newest at the bottom, the last few lines.
func _say(text: String) -> void:
	if not console_lines.is_empty() and console_lines.back() == text:
		return
	console_lines.append(text)
	while _console_rows() > 4 and console_lines.size() > 1:
		console_lines.pop_front()
	console.text = "\n".join(console_lines.map(func(l): return "› " + str(l)))

# Rows the lines take when wrapped at about 50 characters (a little pessimistic).
func _console_rows() -> int:
	var rows := 0
	for line in console_lines:
		rows += int(ceil((str(line).length() + 2) / 50.0))
	return rows

func _flush_note() -> void:
	if note != "":
		_say(note)
		note = ""

func _select(t: int) -> void:
	selected = t
	_refresh()

func _member(c: int) -> void:
	note = ""
	state.toggle_member(selected, c)
	_refresh()

func _soonest() -> void:
	note = ""
	state.start_earliest(selected)
	_refresh()

# The clue is in place from the first question but unreadable (a dot for each letter, so the card keeps its size) until hints are on.
func _show_clue() -> void:
	clue_label.visible = not state.choices_done()
	clue_label.text = "💡 " + (clue_text if hints_on else _masked(clue_text))

func _masked(text: String) -> String:
	var out := ""
	for i in range(text.length()):
		out += text[i] if text[i] == " " else "·"
	return out

# The better of the two answers in front of the player: the one that loses nothing.
func _better_answer() -> int:
	return 0 if int(state.current_step()["options"][0]["loss"]) == 0 else 1

# Two levels of help, both off at the start. Hint is a one-shot: it makes the clue of this question readable (it says what to weigh) and the next question masks it again; Solve marks the better answer, or on the free board names the next piece of the best plan.
func _hint() -> void:
	hints_on = true
	_show_clue()
	_refresh()

func _solve() -> void:
	solve_on = solve_button.button_pressed
	if not solve_on:
		hinted = -1
		_ring_hint()
		_refresh()
		return
	if not edit_card.visible and not state.choices_done():
		hinted = _better_answer()
		note = "Solve: the %s answer is the better one." % ("top" if hinted == 0 else "bottom")
		_refresh()
		_ring_hint()
		return
	var h: Dictionary = state.hint()
	if h.is_empty():
		note = "That is already the best plan there is."
	else:
		selected = int(h["task"])
		var who: Array = []
		for c in range(FAMILY.size()):
			if (int(h["party"]) >> c) & 1 == 1:
				who.append(_who(c))
		note = "Solve: %s %s “%s”, from time %d%s." % [" and ".join(who), "do" if who.size() > 1 else "does", str(state.world["tasks"][selected].get("name", "")).split(":")[0], int(h["start"]), ", performing it" if bool(h["performance"]) else ""]
	_refresh()

func _tidy() -> void:
	state.tidy()
	note = "Tidied: every task now starts as early as it can, with the same people."
	_refresh()

func _nudge(step: int) -> void:
	note = ""
	state.set_start(selected, int(state.picks[selected]["start"]) + step)
	_refresh()

func _perform() -> void:
	state.set_performance(selected, perform_button.button_pressed)
	_refresh()

func _clear() -> void:
	note = ""
	state.clear_all()
	_refresh()

func _best() -> void:
	note = "This is the best plan: no other plan scores more, and the solver has proved it."
	state.load_best()
	_refresh()

func _needs(task: Dictionary) -> String:
	if task["kind"] != "duty":
		return "one of the family"
	var roles := ["tank", "healer", "damage", "support"]
	var parts: Array = []
	for r in range(4):
		if int(task["roles"][r]) > 0:
			parts.append("%s %s" % [ROLE_EMOJI[roles[r]].repeat(int(task["roles"][r])), roles[r]])
	return ", ".join(parts)

func _refresh() -> void:
	var result: Dictionary = state.verdict()
	var flagged := -1
	# a task is flagged when a rule is broken, not when a must-do task simply has not been placed yet
	if not result["allowed"] and int(result.get("task", -1)) >= 0 and str(result["reason"]) != "a required task is not done":
		flagged = int(result["task"])
	for r in range(state.task_count()):
		var t: int = row_task[r]
		var task: Dictionary = state.world["tasks"][t]
		var pick: Button = task_rows[r]["button"]
		pick.text = "%s  %s" % ["⬛" if task["kind"] == "duty" else "🔵", str(task.get("name", "")).split(":")[0]]
		pick.set_pressed_no_signal(t == selected)
		var names: Array = []
		for c in state.members(t):
			names.append(_who(c))
		task_rows[r]["who"].text = "%s · %d" % [", ".join(names) if names.size() <= 2 else "%d people" % names.size(), int(state.picks[t]["start"])] if state.is_done(t) else ("needed" if bool(task["required"]) else "optional")
		task_rows[r]["who"].modulate = Color(1, 1, 1, 1.0 if state.is_done(t) else 0.6)
	var task: Dictionary = state.world["tasks"][selected]
	detail.text = "%s at %s: %s. Takes %d. Worth %d points%s." % [str(task["kind"]).capitalize(), IslandMap.NAMES[int(task["at"]) - 1], _needs(task), int(task["quick"]), int(task["points"]), ", and a bonus of %d if performed" % int(task["bonus"]) if task["kind"] == "scout" and int(task["bonus"]) > 0 else ""]
	for c in range(FAMILY.size()):
		member_buttons[c].set_pressed_no_signal((int(state.picks[selected]["party"]) >> c) & 1 == 1)
		member_buttons[c].disabled = int(task["reach"]) > int(state.world["chars"][c]["reach"])
	var assigned: bool = state.is_done(selected)
	start_label.text = str(int(state.picks[selected]["start"])) if assigned else "-"
	earliest_label.text = "soonest: %d" % state.earliest_start(selected) if assigned else ""
	perform_button.visible = task["kind"] == "scout"
	perform_button.disabled = not assigned
	perform_button.set_pressed_no_signal(bool(state.picks[selected]["performance"]))
	next_button.disabled = not _chapter_done() or chapter >= CHAPTERS.size() - 1
	previous_button.disabled = chapter <= 0
	timeline.selected = selected
	timeline.flagged = flagged
	timeline.refresh()
	map.set_selected(int(task["at"]) - 1)
	if result["allowed"]:
		var best: int = state.best_score()
		dot.color = Look.c("good")
		var stars: int = state.stars()
		verdict.text = "%s  Works · done by time %d · score %d of %d%s" % [_stars_text(stars), int(result["end"]), int(result["score"]), best, "  ·  the best there is" if int(result["score"]) == best else ""]

		_flush_note()
	else:
		dot.color = Look.c("bad") if flagged >= 0 else Look.c("warn")
		verdict.text = "🧭 Not yet: %s" % _friendly(result)
		_flush_note()

# The score worked out where the player sees it at the end: what the tasks earn, what the days cost, the best plan's own sum, what the next star needs, and where the
# points went.
func _score_story(stars: int) -> String:
	var r: Dictionary = state.regret()
	if r.is_empty():
		return ""
	var tw := int(state.world["time_weight"])
	var score := int(state.verdict()["score"])
	var best: int = state.best_score()
	var end := int(r["end"])
	var best_end := int(r["best_end"])
	var lines: Array = ["Score %d: the tasks earn %d, minus %d for the %d days it takes." % [score, score + tw * end, tw * end, end]]
	if score < best:
		lines[0] += " The best plan earns %d in %d days: %d." % [best + tw * best_end, best_end, best]
	if stars < 3 and best > 0:
		var share := 1.0 if stars == 2 else (0.7 if stars == 1 else 0.4)
		var need := int(floor(share * best))
		while float(need) / float(best) < share: # the same test stars() makes, so float rounding cannot ask for one point too many
			need += 1
		lines.append("%s %d." % ["Three stars need" if stars == 2 else ("Two stars need" if stars == 1 else "One star needs"), need])
	lines.append(_where_it_went(r))
	return "\n".join(lines)

# Where the points went, from the model's own best plan: the extra time, then the tasks that earned less, the largest first.
func _where_it_went(r: Dictionary) -> String:
	if r.is_empty() or int(r["gap"]) == 0:
		return "Nothing is left on the table: no plan scores more than this one, and the solver has proved it."
	var parts: Array = []
	if int(r["time_cost"]) > 0:
		parts.append("%d later than the best (-%d)" % [int(r["end"]) - int(r["best_end"]), int(r["time_cost"])])
	for entry in r["losses"]:
		if parts.size() >= 3 or int(entry["loss"]) <= 0:
			break
		var name := str(state.world["tasks"][int(entry["task"])].get("name", "")).split(":")[0]
		parts.append("%s “%s” (-%d)" % [entry["why"], name, int(entry["loss"])])
	return "%d left on the table: %s." % [int(r["gap"]), "; ".join(parts)]

# A refusal in plain words, with what to try.
func _friendly(result: Dictionary) -> String:
	var t := int(result.get("task", -1))
	var name := ""
	if t >= 0:
		name = "“%s”" % str(state.world["tasks"][t].get("name", "")).split(":")[0]
	match str(result["reason"]):
		"a required task is not done":
			return "still to place: %d of %d must-do tasks." % [state.required_total() - state.required_placed(), state.required_total()]
		"a character cannot reach the place in time":
			return "someone cannot get to %s that soon. Try Earliest." % name
		"a character is in two tasks at once":
			return "someone is in two places at once around %s. Try Tidy up." % name
		"too many arms work in one zone":
			return "too many hands in one place at once. Move a task later, or Tidy up."
		"the character's arm does not reach":
			return "%s needs someone with a longer reach." % name
		"a duty needs exactly its role mix":
			return "%s needs: %s." % [name, _needs(state.world["tasks"][t])]
		"a scout is done by exactly one character":
			return "%s is a job for one person." % name
		"this character cannot perform":
			return "only Father and Ernest can perform %s." % name
		"a task needs another task to be done first":
			return "%s needs another task done first. Try Hint." % name
		"a task starts before the one it needs is finished":
			return "%s has to wait for the task it needs. Try Tidy up." % name
		"the task is outside its time window":
			return "%s is out of its time window." % name
	return str(result["reason"])

# ---- two choices at a time ----

func _toggle_edit() -> void:
	edit_card.visible = not edit_card.visible
	choice_card.visible = not edit_card.visible
	_refresh()

func _restart() -> void:
	note = ""
	state.begin_choices()
	selected = 0
	hinted = -1
	edit_card.visible = false
	choice_card.visible = true
	console_lines = []
	_say("Started the chapter again.")
	_show_step()
	_refresh()

# What the player is asked now: a question about one task, and two answers that differ in something they can weigh.
func _show_step() -> void:
	var step: Dictionary = state.current_step()
	if step.is_empty():
		var stars: int = state.stars()
		choice_kicker.text = "ALL CHOSEN"
		choice_prompt.text = "%s  Every decision is made: %d of 3 stars.\n%s" % [_stars_text(stars), stars, _score_story(stars)]
		option_buttons[0].text = "Try again"
		option_buttons[1].text = "Next chapter"
		clue_text = ""
		clue_label.visible = false
		return
	var t: int = int(step["task"])
	var task: Dictionary = state.world["tasks"][t]
	var what := str(task.get("name", "")).split(":")[0]
	var place: String = IslandMap.NAMES[int(task["at"]) - 1]
	var at_place := "" if what.contains(place) else ", at %s" % place # "raise the tent at Tentholm" names its place already
	rule.text = "Score = what the tasks add, minus the time taken. Best: %d." % state.best_score()
	choice_kicker.text = "CHOICE %d OF %d" % [int(step["index"]) + 1, int(step["total"])]
	match str(step["kind"]):
		"perform":
			choice_prompt.text = "%s%s. Do it properly for a bonus, or just take a quick look?" % [what.substr(0, 1).to_upper() + what.substr(1), at_place]
		"skip":
			choice_prompt.text = "Is it worth doing: %s%s? It is not needed to finish the chapter." % [what, at_place]
		_:
			choice_prompt.text = "Who should %s%s? It needs %s." % [what, at_place, _needs(task)]
	hinted = -1
	for k in range(2):
		option_buttons[k].text = _describe(step, k)
	clue_text = state.clue()
	hints_on = false
	_show_clue()
	if solve_on:
		hinted = _better_answer()
	_ring_hint()
	selected = t

# Earned stars as emoji, with an empty circle for each one not yet earned.
func _stars_text(stars: int) -> String:
	return "⭐".repeat(stars) + "⚪".repeat(3 - stars)

# One word for how quickly a family member moves, and the role in the family's own terms.
# A family member as shown: the name and the role's emoji.
func _who(c: int) -> String:
	return "%s %s" % [FAMILY[c], ROLE_EMOJI[FAMILY_ROLE[c]]]

func _trait(c: int) -> String:
	var info: Dictionary = state.world["chars"][c]
	var speed := "quick on foot" if int(info["stride"]) >= 115 else ("steady on foot" if int(info["stride"]) >= 100 else "slower on foot")
	return "%s: %s, %s%s" % [_who(c), str(info["role"]), speed, ", can perform" if bool(info["perform"]) else ""]

# What a task adds to the score: its points count double, and a bonus counts as it is for a duty or a task done properly.
func _worth(task: Dictionary, performed: bool) -> int:
	var v: int = int(state.world["point_weight"]) * int(task["points"])
	if task["kind"] == "duty" or performed:
		v += int(task["bonus"])
	return v

# An answer in words: what it is, and the facts that set it apart from the other answer.
func _describe(step: Dictionary, k: int) -> String:
	var option: Dictionary = step["options"][k]
	var other: Dictionary = step["options"][1 - k]
	var task: Dictionary = state.world["tasks"][int(step["task"])]
	match str(step["kind"]):
		"skip":
			if bool(option.get("skip", false)):
				return "Leave it\nNo one is spent on it."
			return "Do it\nadds %d to the score · takes %d" % [_worth(task, bool(state.best_plan["how"][int(step["task"])] == "PERFORMANCE")), int(option["takes"])]
		"perform":
			if bool(option["performance"]):
				return "Do it properly\ntakes %d · adds %d to the score" % [int(option["takes"]), _worth(task, true)]
			return "A quick look\ntakes %d · adds %d to the score" % [int(option["takes"]), _worth(task, false)]
	var who: Array = []
	for c in range(FAMILY.size()):
		if (int(option["party"]) >> c) & 1 == 1:
			who.append(_who(c))
	# the member who differs between the two answers is the one to read about
	var differing := -1
	for c in range(FAMILY.size()):
		if ((int(option["party"]) >> c) & 1) == 1 and ((int(other["party"]) >> c) & 1) == 0:
			differing = c
	var line := "%s  ·  starts at %d, takes %d" % [" and ".join(who), int(option["start"]), int(option["takes"])]
	return line + ("\n%s; %s" % [_trait(differing), state.need_phrase(differing).replace("has nothing else to do after this", "nothing else to do after this").replace("is needed again for", "needed again for")] if differing >= 0 else "")

func _ring_hint() -> void:
	for k in range(option_buttons.size()):
		option_buttons[k].set_pressed_no_signal(k == hinted)

func _choose(k: int) -> void:
	if state.choices_done():
		if k == 0:
			_restart()
		else:
			_go(1)
		return
	var result: Dictionary = state.choose(k)
	note = str(result["note"])
	hinted = -1
	for button in option_buttons:
		button.set_pressed_no_signal(false)
	_show_step()
	_refresh()
