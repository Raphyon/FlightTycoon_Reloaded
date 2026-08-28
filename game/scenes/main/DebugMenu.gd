extends Control

# One place for every development tool built so far, since the keybinds had
# spread across four editors and were only discoverable by reading source.
# F1 opens it.
#
# Built entirely from code rather than scene nodes: it's dev furniture, so
# keeping it out of Main.tscn means it can't accidentally be styled, moved
# or shipped as part of the real UI, and adding a tool here is one entry in
# the tables below.

const TOGGLE_KEY := KEY_F1
# Width is fixed; HEIGHT IS WHATEVER THE WINDOW HAS. This used to be a fixed
# 430x700 pinned at (240, 120), which on a 720-tall window ran to 820 and put
# the bottom third - the placement tools, then the give controls, then the speed
# controls - off the screen entirely. It grew every time a tool was added, so a
# fixed size was always going to lose this argument eventually.
const PANEL_WIDTH := 430.0
const MARGIN := 16.0

# The overlay flags on DebugState, as checkbox rows.
const FLAGS := [
	{"flag": &"show_grid", "label": "Isometric grid", "key": ""},
	{"flag": &"hide_ui", "label": "Hide all UI (this menu stays)", "key": ""},
	{"flag": &"show_apron_ids", "label": "Apron ID numbers", "key": ""},
	{"flag": &"show_apron_tints", "label": "Apron free/occupied tints", "key": ""},
	{"flag": &"show_apron_costs", "label": "Apron build costs", "key": ""},
]

# The placement editors. Each owns an "editing" bool and its own keybind; the
# menu flips that bool directly so the button and the key stay in sync.
const EDITORS := [
	{
		"node": "ApronLayer", "label": "Apron placement", "key": "",
		"help": "1-7 pick area  ·  click add  ·  click a tile to remove",
	},
	{
		"node": "CloudLayer", "label": "Cloud placement", "key": "",
		"help": "1-7 pick zone  ·  click place/move  ·  click its cloud to remove",
	},
	{
		"node": "PathLayer", "label": "Path tracing", "key": "",
		"help": "1-4 plane paths  ·  5 roads (N new, C category, [ ] switch, X delete)  ·  H clouds",
	},
	{
		"node": "RotorEditor", "label": "Rotor placement", "key": "",
		"help": "M model  ·  1-9 pick rotor  ·  click place  ·  - + disc size  ·  B behind/front",
	},
]

var _speed_buttons: Array = []
var _rows: Array = []


# HAND CONTROLS, rather than the four scenario presets alone. A preset drops you
# at a fixed point and wipes what you had; most testing wants one number nudged -
# enough cash for the next zone, enough levels to see what a gate does - without
# throwing the rest of the save away.
const GIVE_ROWS := [
	{"kind": "cash", "label": "Cash", "amounts": [10000, 100000, 1000000, 10000000]},
	{"kind": "coins", "label": "Coins", "amounts": [5, 10, 50, 100]},
	{"kind": "levels", "label": "Levels", "amounts": [1, 5, 10]},
]


func _ready() -> void:
	visible = false
	# It sits mid-list among UI's children, so twenty-odd panels declared after
	# it would otherwise draw straight over the top. Debug furniture is always
	# the frontmost thing on the screen - including over a panel that is itself
	# only visible because this menu made it so.
	z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	_build()
	DebugState.flags_changed.connect(_refresh)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == TOGGLE_KEY:
		visible = not visible
		if visible:
			_refresh()
		get_viewport().set_input_as_handled()


func _build() -> void:
	# Spans the viewport but ignores the mouse, so only the panel inside it takes
	# clicks - the world behind stays draggable while the menu is open.
	# ...AND_OFFSETS_, not just anchors. The node in Main.tscn carries no size, so
	# setting anchors alone left it 0x0 and the panel anchored to nothing.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = MARGIN
	panel.offset_top = MARGIN
	panel.offset_right = MARGIN + PANEL_WIDTH
	panel.offset_bottom = -MARGIN
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	style.border_color = Color(0.45, 0.5, 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	# Scrolls, so the list can outgrow the window without anything vanishing.
	# Vertical only - a horizontal bar would just hide the labels instead.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(col)

	col.add_child(_heading("DEBUG MENU", 18))
	col.add_child(_note("F1 closes  ·  nothing here is saved between runs"))
	col.add_child(HSeparator.new())

	col.add_child(_heading("Overlays", 14))
	for entry in FLAGS:
		var row := CheckBox.new()
		row.text = entry["label"] if entry["key"] == "" else "%s   [%s]" % [entry["label"], entry["key"]]
		row.toggled.connect(func(on: bool) -> void: DebugState.set_flag(entry["flag"], on))
		col.add_child(row)
		_rows.append({"kind": "flag", "flag": entry["flag"], "control": row})

	col.add_child(HSeparator.new())
	col.add_child(_heading("Time", 14))
	col.add_child(_note("Speeds up flights, rent and the fuel market together."))
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 6)
	col.add_child(speeds)
	for n in GameClock.SPEEDS:
		var b := Button.new()
		b.text = "x%d" % roundi(n)
		b.toggle_mode = true
		b.pressed.connect(_on_speed_pressed.bind(float(n)))
		speeds.add_child(b)
		_speed_buttons.append({"button": b, "value": float(n)})
	_refresh_speeds()

	col.add_child(HSeparator.new())
	col.add_child(_heading("Give", 14))
	col.add_child(_note("Nudge the save by hand. Levels grant the XP to reach them,"
		+ " so every level-up fires as it normally would."))
	for row in GIVE_ROWS:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 6)
		var label := Label.new()
		label.text = str(row["label"])
		label.custom_minimum_size = Vector2(56, 0)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		line.add_child(label)
		for amount in row["amounts"]:
			var b := Button.new()
			b.text = "+%s" % _short(int(amount))
			b.pressed.connect(_on_give_pressed.bind(str(row["kind"]), int(amount)))
			line.add_child(b)
		col.add_child(line)

	col.add_child(HSeparator.new())
	col.add_child(_heading("Daily tasks", 14))
	col.add_child(_note("No toolbar button yet - this is how you reach the panel."))
	var quests_button := Button.new()
	quests_button.text = "Open daily tasks"
	quests_button.pressed.connect(func() -> void:
		var quests_panel := get_node_or_null("../QuestsPanel")
		if quests_panel and quests_panel.has_method("open"):
			quests_panel.open())
	col.add_child(quests_button)
	var roll := Button.new()
	roll.text = "Reroll today's three"
	roll.pressed.connect(func() -> void: Quests.reset())
	col.add_child(roll)

	col.add_child(HSeparator.new())
	col.add_child(_heading("Placement tools", 14))
	col.add_child(_note("Only one should be active at a time - they all claim clicks."))
	for entry in EDITORS:
		var button := Button.new()
		button.toggle_mode = true
		button.pressed.connect(_on_editor_toggled.bind(entry["node"], button))
		col.add_child(button)
		col.add_child(_note("        " + entry["help"]))
		_rows.append({"kind": "editor", "node": entry["node"], "label": entry["label"],
			"key": entry["key"], "control": button})


# 10000 -> "10k", 1000000 -> "1m". A row of full figures is unreadable at this
# size and the button only has to say which of four it is.
func _short(n: int) -> String:
	if n >= 1000000:
		return "%dm" % (n / 1000000)
	if n >= 1000:
		return "%dk" % (n / 1000)
	return str(n)


func _on_give_pressed(kind: String, amount: int) -> void:
	match kind:
		"cash":
			Economy.add_money(amount)
		"coins":
			Coins.add(amount)
		"levels":
			# Granted as XP rather than by setting `level` directly, so add_xp
			# runs its own loop and every level_changed fires - the shop, the
			# zone cards and the quest gates all listen for those.
			var target: int = Progression.level + amount
			Progression.add_xp(maxi(0, Progression.xp_for_level(target) - Progression.xp))
	_refresh()


func _on_speed_pressed(value: float) -> void:
	GameClock.set_scale(value)
	_refresh_speeds()


func _refresh_speeds() -> void:
	for row in _speed_buttons:
		(row["button"] as Button).button_pressed = is_equal_approx(
			GameClock.scale(), float(row["value"]))


func _heading(text: String, size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	return l


func _note(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color(0.62, 0.68, 0.76))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(PANEL_WIDTH - 40, 0)
	return l


func _editor(node_name: String) -> Node:
	return get_node_or_null("../../%s" % node_name)


func _on_editor_toggled(node_name: String, button: Button) -> void:
	var editor := _editor(node_name)
	if not editor:
		return
	var turning_on: bool = button.button_pressed
	# These tools all grab clicks, so leaving two on at once means the first
	# one silently eats everything the second is meant to receive.
	if turning_on:
		for entry in EDITORS:
			if entry["node"] == node_name:
				continue
			var other := _editor(entry["node"])
			if other:
				other.editing = false
	editor.editing = turning_on
	_refresh()


func _refresh() -> void:
	for row in _rows:
		if row["kind"] == "flag":
			row["control"].set_pressed_no_signal(DebugState.get(row["flag"]))
		else:
			var editor := _editor(row["node"])
			var on: bool = editor.editing if editor else false
			row["control"].set_pressed_no_signal(on)
			row["control"].text = "%s   [%s]%s" % [row["label"], row["key"], "   ACTIVE" if on else ""]
