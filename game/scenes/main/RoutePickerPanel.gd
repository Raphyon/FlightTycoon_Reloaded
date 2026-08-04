extends Control

# Setting a route: which aircraft, and where it flies.
#
# Three columns, matching the reference screen - the aircraft on the left with
# its stats, the destination in the middle with its distance, and what the two
# of them add up to on the right. The right column is the point of the screen:
# it is the only place the game tells you what a trip is actually worth before
# you commit to it.
const BOARD := preload("res://assets/board/board_openairline@ipad.png")
const CLOUD := preload("res://assets/bubbles/cloud_icon@2x.png")
const CONFIRM_TEXTURE := preload("res://assets/buttons/button_orange4@2x.png")
const CLEAR_NORMAL := preload("res://assets/buttons/button_red1@2x.png")
const CLEAR_PRESSED := preload("res://assets/buttons/button_red2@2x.png")

const FORCE_ICON := preload("res://assets/hud/stat_force@2x.png")
const MONEY_ICON := preload("res://assets/hud/icon_medium_money1@2x.png")
const FUEL_ICON := preload("res://assets/bubbles/drum_icon@2x.png")
const XP_ICON := preload("res://assets/hud/icon_medium_xp@2x.png")

# The art is 716x358. Everything below is expressed at that native size and
# multiplied by BOARD_SCALE, so resizing the dialog is one number and the type
# and spacing follow it. At 1.5x it was 1074 wide in a 1152 viewport - 93% of
# the screen, which is a full-screen panel wearing a dialog's clothes.
const BOARD_NATIVE := Vector2(716, 358)
const BOARD_SCALE := 1.2
const BOARD_SIZE := Vector2(859, 430)
# Column centres and row positions as fractions of the board, measured off the
# reference so the layout survives being drawn at any size.
const COL_X := [0.162, 0.471, 0.807]
const HEADER_Y := 0.10
const CLOUD_Y := 0.215
const ART_Y := 0.30
const ART_H := 0.26
const NAME_Y := 0.585
const SUB_Y := 0.655
const STAT_Y := 0.72
const DETAIL_Y := 0.30
const DETAIL_STEP := 0.085
const ACTION_Y := 0.72

const CLOUD_SIZE := Vector2(16, 11)
# Native type sizes - _fs() scales them with the board.
const FONT_HEADER := 17
const FONT_NAME := 16
const FONT_SUB := 15
const FONT_DETAIL := 14
const FONT_STAT := 14
# Each button is drawn at ITS OWN native size - orange4 is 192x62 and red1 is
# 136x62, and forcing both into one rectangle stretched the wide one and
# squashed the narrow one. The label shrinks to fit the button instead of the
# button stretching to fit the label.
const ACTION_MAX_FONT := 17
const ACTION_MIN_FONT := 11
const ACTION_PADDING := 20.0

var _apron_id: int = -1
var _aircraft_id: int = -1
# True while the airplane column is showing the list to pick from rather than
# the aircraft you picked.
var _destination: String = ""
var _content: Control


func _ready() -> void:
	visible = false
	custom_minimum_size = BOARD_SIZE
	size = BOARD_SIZE
	var board := TextureRect.new()
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.texture = BOARD
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)
	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	# A dialog over the world, not a full-screen panel - so the round X in the
	# corner rather than the bottom-right back arrow. See CloseButton.
	CloseButton.add_to(self, BOARD_SIZE, hide)


# Native size -> on-screen size.
func _fs(native: int) -> int:
	return maxi(1, roundi(native * BOARD_SCALE))


func show_for_apron(apron_id: int) -> void:
	# Drawn and picked above everything else in UI. Without this the apron
	# panel that opened this dialog sits on top of it - it is later in the
	# scene tree, and siblings draw in tree order - and swallows every click.
	move_to_front()
	_apron_id = apron_id
	var current := Fleet.get_aircraft_at_apron(apron_id)
	# ALWAYS the aircraft on this pad, never one carried over from the last
	# time the panel was open. Keeping the previous selection meant opening a
	# second pad and choosing the same model re-assigned the aircraft already
	# standing on the first one - so you could never field two of a type.
	_aircraft_id = current.id if current else -1
	# An empty pad ASKS which aircraft rather than picking one for you - there
	# is no sensible default, and silently choosing the first idle 328 Jet made
	# the column look like a fixed label instead of a choice.
	_destination = Fleet.destination_of(current) if current else _first_destination()
	visible = true
	_rebuild()


# Every aircraft you could put on this pad: the idle ones, plus whatever is
# already standing here.
# What can be put on THIS pad: anything idle, plus whatever is already here.
# Deliberately not "the currently selected aircraft" - an aircraft parked on
# another pad is in service there and isn't ours to take.
func _selectable() -> Array:
	var out: Array = []
	for a in Fleet.aircraft:
		if a.is_idle() or a.assigned_apron_id == _apron_id:
			out.append(a)
	return out


func _first_destination() -> String:
	var l := Friends.list()
	return str(l[0]) if l.size() > 0 else Maps.ROBOT_MAP


func _cycle_destination() -> void:
	var l := Friends.list()
	if l.is_empty():
		return
	var i := l.find(_destination)
	_destination = str(l[(i + 1) % l.size()])
	_rebuild()


func _rebuild() -> void:
	for c in _content.get_children():
		c.queue_free()
	var a := Fleet.get_aircraft(_aircraft_id)

	_header("airplane", 0)
	_header("destination", 1)
	_header("Detailed information", 2)

	if a == null:
		_centred("No aircraft chosen", COL_X[0], NAME_Y, _fs(FONT_SUB))
	else:
		_aircraft_column(a)
	# Choosing happens in the hangar, not here. The hangar already lists your
	# fleet properly - idle tab, grouped by type, with the art at a readable
	# size - and rebuilding a worse version of it inside a 250px column was
	# never going to beat it.
	_choose_button(a == null)
	_destination_column()
	_details_column(a)
	_hit_area(1, _cycle_destination)


func _aircraft_column(a: FleetAircraft) -> void:
	var entry := ShopCatalog.entry_for(a.model_key)
	_clouds(int(ShopCatalog.stat(a.model_key, "range")), COL_X[0])
	if entry.has("icon"):
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.texture = load("res://assets/shop/%s" % entry["icon"])
		art.size = Vector2(BOARD_SIZE.x * 0.22, BOARD_SIZE.y * ART_H)
		art.position = Vector2(BOARD_SIZE.x * COL_X[0] - art.size.x * 0.5, BOARD_SIZE.y * ART_Y)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(art)
	_centred(str(entry.get("name", a.model_key)), COL_X[0], NAME_Y, _fs(FONT_NAME), true)

	# The same four the reference shows: grade, what a leg pays, what it burns,
	# and the XP - laid out two by two under the name.
	var dest := _destination if _destination != "" else Maps.ROBOT_MAP
	var cells := [
		[FORCE_ICON, Fleet.grade_for(a)],
		[MONEY_ICON, str(Fleet.payout_for(a.model_key, dest))],
		[FUEL_ICON, str(Fleet.fuel_cost(a.model_key, dest))],
		[XP_ICON, str(Fleet.xp_for_claim(a.model_key, dest))],
	]
	for i in cells.size():
		var cx: float = COL_X[0] + (-0.055 if i % 2 == 0 else 0.055)
		var cy: float = STAT_Y + (0.0 if i < 2 else 0.075)
		_stat(cells[i][0], cells[i][1], cx, cy)


# Hands over to the hangar in selection mode and comes back with the answer.
func _choose_button(empty: bool) -> void:
	var native := CONFIRM_TEXTURE.get_size()
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = CONFIRM_TEXTURE
	b.custom_minimum_size = native
	b.size = native
	b.position = Vector2(BOARD_SIZE.x * COL_X[0] - native.x * 0.5, BOARD_SIZE.y * ACTION_Y)
	b.pressed.connect(_open_hangar_chooser)
	_content.add_child(b)
	var text := "Choose aircraft" if empty else "Change aircraft"
	var l := _label(text, _fitted_font(text, native.x - ACTION_PADDING), true)
	l.size = native
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)


func _open_hangar_chooser() -> void:
	hide()
	get_node("../HangarPanel").open_for_selection(_on_hangar_picked)


func _on_hangar_picked(model_key: String) -> void:
	# Reopening via show_for_apron would reset the selection to whatever is on
	# the pad, throwing away the choice just made - so restore the panel
	# directly instead.
	for a in _selectable():
		if a.model_key == model_key:
			_aircraft_id = a.id
			break
	move_to_front()
	visible = true
	_rebuild()


func _destination_column() -> void:
	var info: Dictionary = Friends.info_for(_destination)
	_clouds(Fleet.distance_to(_destination), COL_X[1])
	var avatar_path: String = str(info.get("avatar", ""))
	if avatar_path != "" and ResourceLoader.exists(avatar_path):
		var av := TextureRect.new()
		av.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		av.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		av.texture = load(avatar_path)
		av.size = Vector2(BOARD_SIZE.x * 0.14, BOARD_SIZE.y * ART_H)
		av.position = Vector2(BOARD_SIZE.x * COL_X[1] - av.size.x * 0.5, BOARD_SIZE.y * ART_Y)
		av.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(av)
	_centred(str(info.get("name", _destination)), COL_X[1], NAME_Y, _fs(FONT_NAME), true)
	_centred("Lv.%d" % int(info.get("level", 1)), COL_X[1], SUB_Y, _fs(FONT_SUB))


func _details_column(a: FleetAircraft) -> void:
	if not a:
		return
	var dest := _destination if _destination != "" else Maps.ROBOT_MAP
	var secs := Fleet.flight_seconds_for(a, dest)
	# Revenue as the player will actually receive it: the apron's skin bonus is
	# part of the deal, and the reference shows the total with it applied (a
	# 200-a-leg aircraft on a skinned pad reads 230).
	var bonus := 1.0 + ApronSkins.bonus_percent_for(_apron_id) / 100.0
	# The city's cut too, or this panel would quietly understate every flight -
	# the two multipliers are applied together in Fleet._grant_reward, so they
	# have to be shown together here. Cash only: XP is not multiplied.
	var city := BuildingProgress.popularity_multiplier()
	var rows := [
		["Total Time", _time_text(secs)],
		["Total fuel consumption", str(Fleet.fuel_cost(a.model_key, dest))],
		["Total Revenue", str(roundi(Fleet.payout_for(a.model_key, dest) * bonus * city))],
		["XP revenue", str(roundi(Fleet.xp_for_claim(a.model_key, dest) * bonus))],
	]
	for i in rows.size():
		var y := DETAIL_Y + i * DETAIL_STEP
		var l := _label(rows[i][0], _fs(FONT_DETAIL))
		l.position = Vector2(BOARD_SIZE.x * 0.665, BOARD_SIZE.y * y)
		l.size = Vector2(BOARD_SIZE.x * 0.20, BOARD_SIZE.y * 0.07)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_content.add_child(l)
		var v := _label(rows[i][1], _fs(FONT_DETAIL), true)
		v.position = Vector2(BOARD_SIZE.x * 0.865, BOARD_SIZE.y * y)
		v.size = Vector2(BOARD_SIZE.x * 0.10, BOARD_SIZE.y * 0.07)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_content.add_child(v)
	_action_button(a)


# Reads up to days, not just minutes. A rating-5 aircraft is away for twelve
# hours or more (Fleet.CLOUD_BASE_MINUTES), and "768 minutes" is not a thing
# anyone wants to read off a card.
func _time_text(secs: float) -> String:
	if secs < 60.0:
		return "%d seconds" % roundi(secs)
	if secs < 3600.0:
		var m := secs / 60.0
		return "1 minute" if absf(m - 1.0) < 0.01 else "%.0f minutes" % m
	if secs < 86400.0:
		var h := secs / 3600.0
		return "1 hour" if absf(h - 1.0) < 0.01 else "%.1f hours" % h
	return "%.1f days" % (secs / 86400.0)


# Set the route, or clear it. A pad that already has an aircraft offers the
# red "clear" the reference shows; an empty one offers the orange confirm.
func _action_button(a: FleetAircraft) -> void:
	var assigned := a.assigned_apron_id == _apron_id
	var texture: Texture2D = CLEAR_NORMAL if assigned else CONFIRM_TEXTURE
	# "Delete" alone - the button sits in a route screen, so saying "route"
	# again adds nothing and only crowds the art.
	var text := "Delete" if assigned else "Set route"
	var native := texture.get_size()

	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = texture
	if assigned:
		b.texture_pressed = CLEAR_PRESSED
		b.texture_hover = CLEAR_PRESSED
	b.custom_minimum_size = native
	b.size = native
	b.position = Vector2(BOARD_SIZE.x * COL_X[2] - native.x * 0.5, BOARD_SIZE.y * ACTION_Y)
	b.pressed.connect(_on_clear if assigned else _on_confirm)
	_content.add_child(b)

	var l := _label(text, _fitted_font(text, native.x - ACTION_PADDING), true)
	l.size = native
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)


# Largest size in range whose rendered width fits, so a longer label loses a
# point or two of type rather than pulling the artwork out of shape.
func _fitted_font(text: String, available: float) -> int:
	var font := ThemeDB.fallback_font
	for size in range(ACTION_MAX_FONT, ACTION_MIN_FONT - 1, -1):
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= available:
			return size
	return ACTION_MIN_FONT


func _on_confirm() -> void:
	var a := Fleet.get_aircraft(_aircraft_id)
	if not a:
		return
	a.destination = _destination
	Fleet.assign_to_apron(a.id, _apron_id)
	Fleet.fleet_changed.emit()
	hide()


func _on_clear() -> void:
	var a := Fleet.get_aircraft(_aircraft_id)
	# Only a parked aircraft can be pulled off a pad - one mid-route would
	# simply vanish (Fleet.unassign enforces the same rule).
	if a and a.state == FleetAircraft.State.PARKED:
		Fleet.unassign(a.id)
	hide()


# --- small builders ------------------------------------------------------

func _header(text: String, col: int) -> void:
	_centred(text, COL_X[col], HEADER_Y, _fs(FONT_HEADER), true)


func _centred(text: String, cx: float, y: float, font: int, bold := false) -> void:
	var l := _label(text, font, bold)
	l.size = Vector2(BOARD_SIZE.x * 0.30, BOARD_SIZE.y * 0.08)
	l.position = Vector2(BOARD_SIZE.x * cx - l.size.x * 0.5, BOARD_SIZE.y * y)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(l)


func _label(text: String, font: int, bold := false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.16, 0.28, 1))
	l.add_theme_constant_override("outline_size", 5 if bold else 3)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _clouds(n: int, cx: float) -> void:
	var total := n * CLOUD_SIZE.x + maxf(0.0, n - 1) * 3.0
	var x := BOARD_SIZE.x * cx - total * 0.5
	for i in n:
		var c := TextureRect.new()
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.texture = CLOUD
		c.size = CLOUD_SIZE
		c.position = Vector2(x + i * (CLOUD_SIZE.x + 3.0), BOARD_SIZE.y * CLOUD_Y)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(c)


func _stat(icon: Texture2D, value: String, cx: float, y: float) -> void:
	var ic := TextureRect.new()
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = icon
	ic.size = Vector2(18 * BOARD_SCALE, 20 * BOARD_SCALE)
	ic.position = Vector2(BOARD_SIZE.x * cx - 24 * BOARD_SCALE, BOARD_SIZE.y * y)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(ic)
	var l := _label(value, _fs(FONT_STAT), true)
	l.size = Vector2(70 * BOARD_SCALE, 24 * BOARD_SCALE)
	l.position = Vector2(BOARD_SIZE.x * cx, BOARD_SIZE.y * y)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_content.add_child(l)


# An invisible button covering a whole column, added last so it sits over the
# artwork but below nothing that needs its own clicks.
func _hit_area(col: int, handler: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.modulate = Color(1, 1, 1, 0)
	b.position = Vector2(BOARD_SIZE.x * (COL_X[col] - 0.15), BOARD_SIZE.y * 0.18)
	b.size = Vector2(BOARD_SIZE.x * 0.30, BOARD_SIZE.y * 0.66)
	b.pressed.connect(handler)
	_content.add_child(b)
