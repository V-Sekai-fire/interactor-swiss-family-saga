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
var lost: Label
var dot: ColorRect
var task_rows: Array = []        # per task: {"button": Button, "who": Label}
var detail: Label
var member_buttons: Array = []
var start_label: Label
var earliest_label: Label
var perform_button: Button
var island_edges: Array = []

func _ready() -> void:
	Look.fit(get_window())
	get_window().theme = Look.make()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	Look.sky(self)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, Look.PAGE)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", Look.GAP)
	margin.add_child(page)

	kicker = Look.kicker("")
	page.add_child(kicker)
	var title := Label.new()
	title.text = "The Swiss Family Saga"
	Look.heading(title, Look.T.FONT_SIZE_PANEL_HEADING)
	page.add_child(title)

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
	map.custom_minimum_size = Vector2(500, 190)
	island.add_child(map)
	var plan_box := Look.card(left, "The plan", "", 1)
	timeline = Timeline.new()
	timeline.custom_minimum_size = Vector2(500, 6 * 22 + 20)
	timeline.state = state
	timeline.names = FAMILY
	plan_box.add_child(timeline)
	lost = Label.new()
	Look.muted(lost, 12)
	Look.fixed(lost, 2, 500)
	lost.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	plan_box.add_child(lost)

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
		pick.alignment = HORIZONTAL_ALIGNMENT_LEFT
		pick.clip_text = true
		pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pick.pressed.connect(_select.bind(t))
		row.add_child(pick)
		var who := Label.new()
		Look.muted(who, 12)
		Look.fixed(who, 1, 190)
		who.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(who)
		task_rows.append({"row": row, "button": pick, "who": who})

	var editor := Look.card(right, "Who does it, and when", "", 1)
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
		member.text = FAMILY[c]
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
	for entry in [["Clear", _clear], ["Show the best plan", _best], ["Previous", _go.bind(-1)], ["Next", _go.bind(1)]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		bar.add_child(button)
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
	var bare := Look.box(Color(0, 0, 0, 0), 8, Color(0, 0, 0, 0), 6)
	b.add_theme_stylebox_override("normal", bare)
	b.add_theme_stylebox_override("hover", Look.box(Color(Look.c("paper"), 0.6), 8, Color(0, 0, 0, 0), 6))
	b.add_theme_stylebox_override("pressed", Look.box(Look.c("paper"), 8, Look.c("ink"), 6))
	b.add_theme_stylebox_override("hover_pressed", Look.box(Look.c("paper"), 8, Look.c("ink"), 6))
	for colour_name in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(colour_name, Look.c("ink"))

func _load(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://conformance/%s.json" % file))

func _open_chapter() -> void:
	state.load_chapter(_load(CHAPTERS[chapter][0]))
	if island_edges.is_empty():
		island_edges = _load("ch07_cape")["world"]["edges"]
	selected = 0
	kicker.text = "CHAPTER %d OF %d · %s" % [chapter + 1, CHAPTERS.size(), str(CHAPTERS[chapter][1]).to_upper()]
	premise.text = PREMISES[chapter]
	map.set_world(state.world, island_edges)
	for t in range(task_rows.size()):
		task_rows[t]["row"].visible = t < state.task_count()
	_refresh()

func _go(step: int) -> void:
	chapter = posmod(chapter + step, CHAPTERS.size())
	_open_chapter()

func _select(t: int) -> void:
	selected = t
	_refresh()

func _member(c: int) -> void:
	state.toggle_member(selected, c)
	_refresh()

func _nudge(step: int) -> void:
	state.set_start(selected, int(state.picks[selected]["start"]) + step)
	_refresh()

func _perform() -> void:
	state.set_performance(selected, perform_button.button_pressed)
	_refresh()

func _clear() -> void:
	state.clear_all()
	_refresh()

func _best() -> void:
	state.load_best()
	_refresh()

func _needs(task: Dictionary) -> String:
	if task["kind"] != "duty":
		return "one of the family"
	var roles := ["tank", "healer", "damage", "support"]
	var parts: Array = []
	for r in range(4):
		if int(task["roles"][r]) > 0:
			parts.append("%d %s" % [int(task["roles"][r]), roles[r]])
	return ", ".join(parts)

func _refresh() -> void:
	var result: Dictionary = state.verdict()
	var flagged := -1
	if not result["allowed"] and int(result.get("task", -1)) >= 0:
		flagged = int(result["task"])
	for t in range(state.task_count()):
		var task: Dictionary = state.world["tasks"][t]
		var pick: Button = task_rows[t]["button"]
		pick.text = "%s  %s" % ["■" if task["kind"] == "duty" else "○", str(task.get("name", "")).split(":")[0]]
		pick.set_pressed_no_signal(t == selected)
		var names: Array = []
		for c in state.members(t):
			names.append(FAMILY[c])
		task_rows[t]["who"].text = "%s · %d" % [", ".join(names), int(state.picks[t]["start"])] if state.is_done(t) else ("needed" if bool(task["required"]) else "optional")
		task_rows[t]["who"].modulate = Color(1, 1, 1, 1.0 if state.is_done(t) else 0.6)
	var task: Dictionary = state.world["tasks"][selected]
	detail.text = "%s at %s: %s. Takes %d. Worth %d points%s." % [str(task["kind"]).capitalize(), IslandMap.NAMES[int(task["at"]) - 1], _needs(task), int(task["quick"]), int(task["points"]), ", and a bonus of %d if performed" % int(task["bonus"]) if task["kind"] == "scout" and int(task["bonus"]) > 0 else ""]
	for c in range(FAMILY.size()):
		member_buttons[c].set_pressed_no_signal((int(state.picks[selected]["party"]) >> c) & 1 == 1)
		member_buttons[c].disabled = int(task["reach"]) > int(state.world["chars"][c]["reach"])
	var assigned: bool = state.is_done(selected)
	start_label.text = str(int(state.picks[selected]["start"])) if assigned else "-"
	earliest_label.text = ""
	perform_button.visible = task["kind"] == "scout"
	perform_button.disabled = not assigned
	perform_button.set_pressed_no_signal(bool(state.picks[selected]["performance"]))
	timeline.selected = selected
	timeline.flagged = flagged
	timeline.refresh()
	map.set_selected(int(task["at"]) - 1)
	if result["allowed"]:
		var best: int = state.best_score()
		dot.color = Look.c("good")
		verdict.text = "Allowed · done by time %d · score %d of %d%s" % [int(result["end"]), int(result["score"]), best, "  ·  the best there is" if int(result["score"]) == best else ""]
		lost.text = _where_it_went(state.regret())
	else:
		dot.color = Look.c("bad") if flagged >= 0 else Look.c("warn")
		var where := ""
		if flagged >= 0:
			where = " (task %d)" % (flagged + 1)
		verdict.text = "Not yet: %s%s" % [str(result["reason"]), where]
		lost.text = "Once the plan is allowed, this shows exactly where it falls short of the best there is."

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
