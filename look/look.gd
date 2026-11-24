extends RefCounted
# The Chibifire design system in Godot: the tokens (tokens.gd, generated) as a Theme, and the parts a tool window is
# built from. Two schemes: "paper-and-ink" (light, the default) and "observatory" (dark: night, brass and chalk).
#   const Look = preload("res://look/look.gd")      (copy dist/godot/ and fonts/ into the project as res://look and res://fonts)
#   Look.fit(root)                 the window scales its content from the design size; call before building controls
#   Look.scheme("observatory")     the dark scheme (before Look.make(); colours at run time come from Look.c("paper"))
#   root.theme = Look.make()
#   var page := Look.sky(root)     the ground of the window: the paper, or the night with its glow and its stars
#   on it a MarginContainer with Look.PAGE margins and a VBoxContainer with Look.GAP between rows:
#   Look.kicker("MASK STAGE · GUEST ON THE GPU"), a Label with Look.heading(label, Look.T.FONT_SIZE_PANEL_HEADING),
#   then cards: var box := Look.card(parent, "Model", "One line under the heading.")
#   Look.big(box, "views done") for a leading number, Look.muted(label) for mono detail lines,
#   Look.fixed(label, lines, width) on every label whose text changes, so that no card ever changes its size.
# Rules a window must keep (README, "Tool windows"): it shows useful content or it is not opened; nothing wraps or
# overflows; text that changes sits in fixed-size labels; the window never stops for slow work.
# Fonts: Marcellus (headings; Cormorant Garamond 600 in the observatory), IBM Plex Sans (text), IBM Plex Mono (labels,
# buttons, numbers); SIL Open Font License 1.1.

const T = preload("tokens.gd")
const PAPER := T.COLOR_PAPER
const PAPER_2 := T.COLOR_PAPER_2
const CARD := T.COLOR_CARD
const LINE := T.COLOR_LINE
const INK := T.COLOR_INK
const MUTE := T.COLOR_MUTE
const LIT := T.COLOR_LIT
const PAGE := T.SPACE_PAGE
const GAP := T.SPACE_GAP
const FONTS := "res://fonts/"

# The scheme. The constants above are the paper and ink colours, for code that needs a constant. Everything in this file
# reads the scheme in use: call Look.scheme("observatory") before Look.make(), read Look.c("paper") where a colour is
# needed at run time, and Look.t("RADIUS_CARD") for a token the observatory changes (a radius, a size, a weight).
static var observatory := false

static func scheme(name) -> void:
	observatory = (name is bool and name) or (name is String and name in ["observatory", "dark"])

static func c(name: String) -> Color:
	return (T.OBSERVATORY if observatory else T.PAPER_AND_INK)[name]

static func t(name: String) -> Variant:
	if observatory and T.OBSERVATORY_T.has(name):
		return T.OBSERVATORY_T[name]
	var tokens: Script = T
	return tokens.get_script_constant_map()[name]

# The serif of the scheme: Marcellus, or Cormorant Garamond at the heading weight in the observatory.
static func serif() -> Font:
	if not observatory:
		return font("Marcellus-Regular.ttf")
	var base := font("CormorantGaramond[wght].ttf")
	if base == null:
		return font("Marcellus-Regular.ttf")
	var v := FontVariation.new()
	v.base_font = base
	v.variation_opentype = {"wght": int(t("FONT_WEIGHT_HEADING"))}
	return v

# ---- the ground of a window, and the face of a card --------------------------------------------------------------
# Drawn with canvas items only (a gradient texture, circles, a polygon with a colour at each corner): no material and no
# shader of its own, because in this engine a new shader stops the window for seconds the first time it is drawn.

# The stars of the observatory: two-pixel dots of the star colour at fixed places (a seeded sequence, so the sky is the
# same on every run), each dimming to about a quarter and back in four seconds.
class Stars extends Control:
	const COUNT := 80
	const PERIOD := 4.0
	var at := PackedVector2Array()
	var phase := PackedFloat32Array()
	var tint := Color.WHITE
	var still := false # no twinkle: for pictures that must be the same twice, and for readers who ask for less motion

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var k := 7
		for i in COUNT * 3:
			k = (k * 16807) % 2147483647
			var r := float(k) / 2147483647.0
			if i % 3 == 0:
				at.append(Vector2(r, 0.0))
			elif i % 3 == 1:
				at[at.size() - 1].y = r
			else:
				phase.append(r)

	func _process(_dt: float) -> void:
		if not still and is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		var now := 0.0 if still else Time.get_ticks_msec() / 1000.0
		for i in at.size():
			var w := 0.5 + 0.5 * cos(TAU * (now / PERIOD + phase[i]))
			draw_circle(at[i] * size, 1.0, Color(tint, tint.a * lerpf(0.24, 1.0, w)))

# The face of a card in the observatory: the card's top colour running down to its bottom colour inside the border, and a
# line of light under the top edge. The border and the corners are the panel's own style box.
class CardFace extends PanelContainer:
	var top := Color.WHITE
	var bottom := Color.WHITE
	var light := Color(1, 1, 1, 0)
	var radius := 10.0

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var rad := minf(radius - 1.0, minf(r.size.x, r.size.y) * 0.5)
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var corners := [r.position + Vector2(rad, rad), Vector2(r.end.x - rad, r.position.y + rad), r.end - Vector2(rad, rad), Vector2(r.position.x + rad, r.end.y - rad)]
		for q in 4:
			for step in 7:
				var a := PI + q * PI * 0.5 + step * PI / 12.0
				var p: Vector2 = corners[q] + Vector2(cos(a), sin(a)) * rad
				pts.append(p)
				cols.append(top.lerp(bottom, clampf((p.y - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
		draw_polygon(pts, cols)
		if light.a > 0.0:
			draw_line(Vector2(r.position.x + rad, r.position.y + 0.5), Vector2(r.end.x - rad, r.position.y + 0.5), light, 1.0)

# The ground of a window, added under `parent` and filling it: the paper; in the observatory the night with the dusk
# glowing low and to the right, and the stars. Returns the ground: build the page on it.
static func sky(parent: Node, still_stars := false) -> Control:
	var ground := ColorRect.new()
	ground.color = c("paper")
	ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(ground)
	if c("sky-low") != c("paper"):
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 0.8])
		g.colors = PackedColorArray([c("sky-low"), c("sky-mid"), c("paper")])
		var tex := GradientTexture2D.new()
		tex.gradient = g
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.7, 1.2)
		tex.fill_to = Vector2(1.9, 1.2) # the page's corner farthest from the glow is where the night is whole
		tex.width = 256
		tex.height = 256
		var glow := TextureRect.new()
		glow.texture = tex
		glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glow.stretch_mode = TextureRect.STRETCH_SCALE
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ground.add_child(glow)
	if c("star").a > 0.0:
		var stars := Stars.new()
		stars.tint = c("star")
		stars.still = still_stars
		stars.set_anchors_preset(Control.PRESET_FULL_RECT)
		ground.add_child(stars)
	return ground

# The window scales its content from the design size, so a panel laid out for 1180 x 780 fits a smaller window, a larger
# one, and a display at 125 % or 150 % without overflowing. Call it before the controls are built.
static func fit(window: Window, design := Vector2i(T.WINDOW_DESIGN_WIDTH, T.WINDOW_DESIGN_HEIGHT)) -> void:
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	window.content_scale_size = design
	window.min_size = Vector2i(design.x / 2, design.y / 2)

static func font(file: String) -> FontFile:
	var f := FontFile.new()
	if f.load_dynamic_font(FONTS + file) != OK:
		return null
	return f

static func box(bg: Color, radius: int, border := Color(0, 0, 0, 0), pad := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(1)
	s.set_content_margin_all(pad)
	return s

static func make() -> Theme:
	var th := Theme.new()
	var sans := font("IBMPlexSans.ttf")
	var mono := font("IBMPlexMono-Regular.ttf")
	if sans != null:
		th.default_font = sans
	th.default_font_size = 14
	var card := box(c("card-top"), int(t("RADIUS_CARD")), c("line"), 18)
	card.content_margin_left = 20
	card.content_margin_right = 20
	th.set_stylebox("panel", "PanelContainer", card)
	th.set_color("font_disabled_color", "CheckBox", c("line"))
	for cls in ["Label", "CheckBox", "OptionButton", "PopupMenu"]:
		th.set_color("font_color", cls, c("ink"))
		th.set_color("font_hover_color", cls, c("ink"))
		th.set_color("font_pressed_color", cls, c("ink"))
		th.set_color("font_hover_pressed_color", cls, c("ink"))
		th.set_color("font_focus_color", cls, c("ink"))
	th.set_color("font_hover_color", "PopupMenu", c("lit"))
	th.set_stylebox("panel", "PopupMenu", box(c("card"), 8, c("line"), 6))
	th.set_stylebox("hover", "PopupMenu", box(c("paper-2"), 4))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		th.set_stylebox(state, "Button", box(c("button-hover") if state == "hover" else c("button"), 8, Color(0, 0, 0, 0), 8))
		th.set_stylebox(state, "OptionButton", box(c("paper-2"), 8, c("line") if state != "hover" else c("lit"), 7))
		th.set_stylebox(state, "CheckBox", StyleBoxEmpty.new())
	for key in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		th.set_color(key, "Button", c("button-text"))
	if mono != null:
		th.set_font("font", "Button", mono)
	th.set_font_size("font_size", "Button", 13)
	th.set_stylebox("slider", "HSlider", box(c("line"), 2, Color(0, 0, 0, 0), 2))
	th.set_stylebox("grabber_area", "HSlider", box(c("ink"), 2, Color(0, 0, 0, 0), 2))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(c("lit"), 2, Color(0, 0, 0, 0), 2))
	th.set_stylebox("background", "ProgressBar", box(c("paper-2"), 4, c("line")))
	th.set_stylebox("fill", "ProgressBar", box(c("lit"), 4))
	th.set_color("font_color", "ProgressBar", c("ink"))
	return th

# the small upper-case label above a heading
static func kicker(text: String) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	var mono := font("IBMPlexMono-Regular.ttf")
	if mono != null:
		l.add_theme_font_override("font", mono)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", c("kicker"))
	return l

static func heading(l: Label, size: int) -> void:
	var f := serif()
	if f != null:
		l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c("heading"))

static func muted(l: Label, size := 12) -> void:
	var mono := font("IBMPlexMono-Regular.ttf")
	if mono != null:
		l.add_theme_font_override("font", mono)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", c("mute"))

# a card of the deck: a heading (h3), an optional muted line under it (.lab), then the content; returns the content box
# The line under the heading is one line and is cut with an ellipsis: a wrapped line would change the card's height.
# Give lab_lines = 2 for a sentence that needs two.
static func card(parent: Control, title: String, lab := "", lab_lines := 1) -> VBoxContainer:
	var panel: PanelContainer
	if c("card-top") != c("card"):
		# a face that runs from one colour to another: drawn by CardFace inside a border that has no fill
		var face := CardFace.new()
		face.top = c("card-top")
		face.bottom = c("card")
		face.radius = float(t("RADIUS_CARD"))
		var edge := box(Color(0, 0, 0, 0), int(t("RADIUS_CARD")), c("line"), int(T.SPACE_CARD_Y))
		edge.draw_center = false
		edge.content_margin_left = T.SPACE_CARD_X
		edge.content_margin_right = T.SPACE_CARD_X
		face.add_theme_stylebox_override("panel", edge)
		face.light = Color(c("lit-hi"), 0.18)
		panel = face
	else:
		panel = PanelContainer.new()
	parent.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)
	var h := Label.new()
	h.text = title
	heading(h, 24)
	box.add_child(h)
	if lab != "":
		var l := Label.new()
		l.text = lab
		l.add_theme_font_size_override("font_size", T.FONT_SIZE_LABEL)
		l.add_theme_color_override("font_color", c("mute"))
		box.add_child(l)
		if lab_lines > 1:
			l.autowrap_mode = TextServer.AUTOWRAP_WORD
			l.max_lines_visible = lab_lines
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		else:
			fixed(l, 1)
	return box

# one dot of the row at the bottom (#nav b): 10 px, a 1 px ink ring, filled for the current one
static func dot(on: bool) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(10, 10)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var s := box(c("ink") if on else Color(0, 0, 0, 0), 5, c("lit") if state == "hover" else c("ink"))
		b.add_theme_stylebox_override(state, s)
	return b

# the big number of a card (.big) with its line under it (.lab); returns the number's label
static func big(parent: Control, lab: String) -> Label:
	var n := Label.new()
	var mono := font("IBMPlexMono-Medium.ttf")
	if mono != null:
		n.add_theme_font_override("font", mono)
	n.add_theme_font_size_override("font_size", 30)
	parent.add_child(n)
	var l := Label.new()
	l.text = lab
	l.add_theme_font_size_override("font_size", 13)
	l.add_theme_color_override("font_color", c("mute"))
	parent.add_child(l)
	return n

# A label whose text may change without changing the size of its card: a fixed number of lines, clipped at the card's width.
static func fixed(l: Label, lines: int, width := 0) -> void:
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l.max_lines_visible = lines
	var f := l.get_theme_font("font")
	var size := l.get_theme_font_size("font_size")
	var h := (f.get_height(size) if f != null else size * 1.4) * lines + l.get_theme_constant("line_spacing") * (lines - 1)
	l.custom_minimum_size = Vector2(width, ceil(h))
