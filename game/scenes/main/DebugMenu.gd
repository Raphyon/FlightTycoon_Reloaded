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
const PANEL_SIZE := Vector2(430, 610)

# The overlay flags on DebugState, as checkbox rows.
const FLAGS := [
	{"flag": &"show_grid", "label": "Isometric grid", "key": "G"},
	{"flag": &"show_apron_ids", "label": "Apron ID numbers", "key": ""},
	{"flag": &"show_apron_tints", "label": "Apron free/occupied tints", "key": ""},
	{"flag": &"show_apron_costs", "label": "Apron build costs", "key": ""},
]

# The placement editors. Each owns an "editing" bool and its own keybind; the
# menu flips that bool directly so the button and the key stay in sync.
const EDITORS := [
	{
		"node": "ApronEditor", "label": "Apron placement", "key": "P",
		"help": "1-7 pick area  ·  click add  ·  click a tile to remove",
	},
	{
		"node": "CloudEditor", "label": "Cloud placement", "key": "O",
		"help": "1-7 pick zone  ·  click place/move  ·  click its cloud to remove",
	},
	{
		"node": "PathEditor", "label": "Path tracing", "key": "T",
		"help": "1-4 plane paths  ·  5 roads (N new, C category, [ ] switch, X delete)  ·  H clouds",
	},
	{
		"node": "LandmarkEditor", "label": "Landmark placement", "key": "L",
		"help": "click place/move  ·  M next  ·  - + resize  ·  X delete",
	},
	{
		"node": "RotorEditor", "label": "Rotor placement", "key": "R",
		"help": "M model  ·  1-9 pick rotor  ·  click place  ·  - + disc size  ·  B behind/front",
	},
]

var _scenario_buttons: Array = []
var _armed_scenario := ""
var _rows: Array = []


func _ready() -> void:
	visible = false
	_build()
	DebugState.flags_changed.connect(_refresh)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == TOGGLE_KEY:
		visible = not visible
		if visible:
			_refresh()
		get_viewport().set_input_as_handled()


func _build() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(240, 120)
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.06, 0.08, 0.94)
	style.border_color = Color(0.45, 0.5, 0.58)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	panel.add_child(col)

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
	col.add_child(_heading("Jump to a scenario", 14))
	col.add_child(_note("Wipes the save and rebuilds it. There is no undo - see Scenarios.gd."))
	for key in Scenarios.names():
		var b := Button.new()
		b.text = Scenarios.label_for(key)
		b.pressed.connect(_on_scenario_pressed.bind(key))
		col.add_child(b)
		_scenario_buttons.append({"button": b, "key": key})

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


# Two presses, like every other destructive control here - the first arms the
# button and the second does it. A scenario throws away whatever you were
# holding, and these sit one row above the placement tools.
func _on_scenario_pressed(key: String, ) -> void:
	if _armed_scenario != key:
		_armed_scenario = key
		_refresh_scenario_labels()
		return
	_armed_scenario = ""
	Scenarios.apply(key)
	_refresh_scenario_labels()
	visible = false


func _refresh_scenario_labels() -> void:
	for row in _scenario_buttons:
		var b: Button = row["button"]
		var key: String = row["key"]
		b.text = ("Confirm - wipe and load \"%s\"" % Scenarios.label_for(key)
			if _armed_scenario == key else Scenarios.label_for(key))


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
	l.custom_minimum_size = Vector2(PANEL_SIZE.x - 40, 0)
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
