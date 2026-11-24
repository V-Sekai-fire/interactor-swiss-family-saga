# SPDX-FileCopyrightText: 2026 K. S. Ernest (iFire) Lee
# SPDX-License-Identifier: Apache-2.0 OR MIT
# The first screen of the game, in the Chibifire design system: the chapter and its island, the six members of the family, what the chapter asks of them, and the
# checker's verdict on the plan the model found for it.
extends Control

const Look = preload("res://look/look.gd")
const CheckerScript := preload("res://game/scripts/checker.gd")
const IslandMap := preload("res://game/scripts/island_map.gd")
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
var kicker: Label
var map: Control
var verdict: Label
var dot: ColorRect
var premise: Label
var tasks_box: VBoxContainer
var cards: Array = []
var swatches: Array = []
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

	var island := Look.card(body, "The island", "", 1)
	island.get_parent().size_flags_horizontal = Control.SIZE_EXPAND_FILL
	premise = Label.new()
	Look.muted(premise, 13)
	premise.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	premise.custom_minimum_size = Vector2(540, 0)
	island.add_child(premise)
	map = IslandMap.new()
	map.custom_minimum_size = Vector2(560, 380)
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	island.add_child(map)
	var legend := Label.new()
	legend.text = "Squares are duties, rings are scouting, faint ones are optional. Dashed paths cross water."
	Look.muted(legend, Look.T.FONT_SIZE_HINT)
	island.add_child(legend)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", Look.GAP)
	body.add_child(right)
	var family := GridContainer.new()
	family.columns = 2
	family.add_theme_constant_override("h_separation", Look.GAP)
	family.add_theme_constant_override("v_separation", Look.GAP)
	right.add_child(family)
	for name in FAMILY:
		var box := Look.card(family, name, "", 1)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(10, 10)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		swatches.append(swatch)
		var line := Label.new()
		Look.muted(line, 12)
		Look.fixed(line, 1, 170)
		row.add_child(line)
		cards.append(line)
	tasks_box = Look.card(right, "What must be done", "", 1)

	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", Look.GAP)
	page.add_child(bar)
	var previous := Button.new()
	previous.text = "Previous"
	previous.pressed.connect(_go.bind(-1))
	bar.add_child(previous)
	dot = ColorRect.new()
	dot.custom_minimum_size = Vector2(12, 12)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(dot)
	verdict = Label.new()
	Look.muted(verdict, 13)
	verdict.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(verdict)
	var next := Button.new()
	next.text = "Next"
	next.pressed.connect(_go.bind(1))
	bar.add_child(next)
	_show()

func _go(step: int) -> void:
	chapter = posmod(chapter + step, CHAPTERS.size())
	_show()

func _load(file: String) -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://conformance/%s.json" % file))

func _show() -> void:
	var data: Dictionary = _load(CHAPTERS[chapter][0])
	if island_edges.is_empty():
		island_edges = _load("ch07_cape")["world"]["edges"]
	var world: Dictionary = data["world"]
	kicker.text = "CHAPTER %d OF %d · %s" % [chapter + 1, CHAPTERS.size(), str(CHAPTERS[chapter][1]).to_upper()]
	map.set_world(world, island_edges)
	premise.text = PREMISES[chapter]
	for i in range(FAMILY.size()):
		var c: Dictionary = world["chars"][i]
		cards[i].text = "%s · reach %d" % [str(c["role"]).to_upper(), int(c["reach"])]
		swatches[i].color = Look.c(ROLE_COLOURS[str(c["role"])])
	_list_tasks(world["tasks"])
	var result: Dictionary = CheckerScript.check(world, data["cases"][0]["plan"])
	var ok: bool = result["allowed"] and int(result["objective"]) == int(data["optimum"])
	dot.color = Look.c("good") if ok else Look.c("bad")
	verdict.text = "The model's best plan: %s, finishing at time %d, score %d" % ["allowed" if result["allowed"] else "refused", int(result.get("end", 0)), int(result.get("objective", 0))]

# One row per task: a square for a duty, a ring for scouting, faint when it is optional, then what it is called.
func _list_tasks(tasks: Array) -> void:
	for child in tasks_box.get_children():
		if child.has_meta("task_row"):
			tasks_box.remove_child(child)
			child.queue_free()
	for task in tasks:
		var row := Label.new()
		row.set_meta("task_row", true)
		row.text = "%s  %s" % ["■" if task["kind"] == "duty" else "○", str(task.get("name", "")).split(":")[0]]
		Look.muted(row, 13)
		row.clip_text = true
		row.custom_minimum_size = Vector2(430, 0)
		if not bool(task["required"]):
			row.modulate = Color(1, 1, 1, 0.55)
		tasks_box.add_child(row)
