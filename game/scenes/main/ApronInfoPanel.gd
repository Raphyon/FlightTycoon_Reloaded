extends Control

# What's on this pad, and the two things you can change about it.
#
# Rebuilt on board_buildinginfo@2x, replacing a 620x210 stack of containers - a
# title bar, three columns each with its own label, and two full-width buttons
# under them. That carried a lot of furniture for a screen that answers one
# question, and covered a third of the play area doing it.
#
# The layout is the reference's: the two slots and their buttons on the left,
# the aircraft's status and its one action on the right. Everything is placed
# as a fraction of the board and multiplied by BOARD_SCALE, the same way
# RoutePickerPanel does it, so resizing the dialog is one number and the type
# and spacing follow it.
const BOARD := preload("res://assets/board/board_buildinginfo@2x.png")

# Both slots ship an empty and a filled frame - dark with a plain tab when
# nothing is in them, gold with a coloured tab when something is. Swapping the
# frame is what makes a filled slot read as filled at a glance, rather than
# relying on the preview thumbnail alone.
const PLANE_FRAME_EMPTY := preload("res://assets/board/board_apron_info_icon1@2x.png")
const PLANE_FRAME_FILLED := preload("res://assets/board/board_apron_info_icon2@2x.png")
const SKIN_FRAME_EMPTY := preload("res://assets/board/board_apron_info_icon3@2x.png")
const SKIN_FRAME_FILLED := preload("res://assets/board/board_apron_info_icon4@2x.png")
# Two widths of the same button, and each is drawn at ITS OWN aspect - orange2
# is 136x62 and orange4 is 192x62. Forcing one of them into a rectangle we
# picked is what "it looks really bad stretched" meant, twice.
const BUTTON_TEXTURE := preload("res://assets/buttons/button_orange2@2x.png")
const WIDE_BUTTON_TEXTURE := preload("res://assets/buttons/button_orange4@2x.png")
# The route preview: you on the left, where it flies on the right. avatar_nil
# is the blue "?" - shown when the pad has no route yet, which is exactly what
# the reference puts there.
const AVATAR_FRAME := preload("res://assets/player_avatar/avatar_frame@2x.png")
const AVATAR_PLAYER := preload("res://assets/player_avatar/avatar1@2x.png")
const AVATAR_NONE := preload("res://assets/player_avatar/avatar_nil@2x.png")

const BOARD_NATIVE := Vector2(731, 177)
# 0.82 of the art: 599x145 against the old panel's 620x210. Slightly narrower,
# and a third shorter - the height is where "bulky" was really coming from.
const BOARD_SCALE := 0.82
const BOARD_SIZE := Vector2(599, 145)

# Fractions of the board, measured off the reference: two slots hard left with
# a button under each, and the whole right half free for the status line.
const SLOT_Y := 0.13
const SLOT_H := 0.45
# Skin first, aircraft second - the order the reference shows, readable from
# the frames' own tabs: icon3/4 wears a plain swatch, icon1/2 wears a plane.
const SKIN_X := 0.065
const PLANE_X := 0.305
const SLOT_W := 0.20
const BUTTON_Y := 0.64
# Height only - each button's width follows its own art, see _button.
# The route preview occupies the right third: two avatar tiles with the status
# between them - "a timer inbetween, or a message saying arrived".
const AVATAR_FROM_X := 0.555
const AVATAR_TO_X := 0.805
const AVATAR_Y := 0.11
const AVATAR_W := 0.115
const AVATAR_H := 0.47
# The gap BETWEEN the two tiles, which is all the room there is - so what goes
# here has to be a word or a clock, never a sentence. It is information only:
# what the aircraft needs DOING is offered by its bubble on the pad and by the
# routes table, not here.
const STATUS_X := 0.665
const STATUS_Y := 0.27
const ACTION_Y := 0.64

const FONT_TITLE := 15
const FONT_STATUS := 14
const FONT_BUTTON := 13
const FONT_MIN := 9
const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 1)

var _apron_id: int = -1
var _apron: Apron
var _content: Control

var _title: Label
var _plane_frame: TextureRect
var _plane_icon: TextureRect
var _skin_frame: TextureRect
var _skin_preview: TextureRect
var _plane_button: TextureButton
var _plane_label: Label
var _skin_button: TextureButton
var _skin_label: Label
var _from_frame: TextureRect
var _from_avatar: TextureRect
var _to_frame: TextureRect
var _to_avatar: TextureRect
var _status: Label
var _action_button: TextureButton
var _action_label: Label


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
	_build()

	Fleet.fleet_changed.connect(_refresh)
	# Closing counts too - the countdown has to come off the pad when its menu
	# goes away, and hide() is called from several places.
	visibility_changed.connect(func() -> void:
		if not visible:
			shown_apron_changed.emit(-1))
	ApronProgress.built_changed.connect(_refresh)
	ApronSkins.skin_changed.connect(_refresh)


func _px(fx: float, fy: float) -> Vector2:
	return Vector2(BOARD_SIZE.x * fx, BOARD_SIZE.y * fy)


func _fs(native: int) -> int:
	return maxi(FONT_MIN, roundi(native * BOARD_SCALE))


func _build() -> void:
	_title = _label(_fs(FONT_TITLE), HORIZONTAL_ALIGNMENT_LEFT)
	_title.position = _px(0.065, 0.0)
	_title.size = _px(0.4, 0.13)

	_skin_frame = _frame(SKIN_X)
	_skin_preview = _preview(SKIN_X, 0.02)
	_plane_frame = _frame(PLANE_X)
	_plane_icon = _preview(PLANE_X, 0.035)

	var sb := _button(SKIN_X + SLOT_W * 0.5, BUTTON_Y, BUTTON_TEXTURE)
	_skin_button = sb[0]
	_skin_label = sb[1]
	_skin_button.pressed.connect(_on_skin_button_pressed)

	var pb := _button(PLANE_X + SLOT_W * 0.5, BUTTON_Y, BUTTON_TEXTURE)
	_plane_button = pb[0]
	_plane_label = pb[1]
	_plane_button.pressed.connect(_on_plane_button_pressed)

	_from_frame = _avatar_tile(AVATAR_FROM_X)
	_from_avatar = _avatar_art(AVATAR_FROM_X)
	_from_avatar.texture = AVATAR_PLAYER
	_to_frame = _avatar_tile(AVATAR_TO_X)
	_to_avatar = _avatar_art(AVATAR_TO_X)

	# Sits between the two tiles: an arrow when nothing is happening, the
	# countdown while it flies, the outcome when it lands.
	_status = _label(_fs(FONT_STATUS), HORIZONTAL_ALIGNMENT_CENTER)
	_status.position = _px(STATUS_X, STATUS_Y)
	_status.size = _px(AVATAR_TO_X - STATUS_X, 0.20)
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	# The wide art, because "Build ($1200)" does not fit the narrow one - and
	# the label shrinks to the button rather than the button stretching to the
	# label.
	var ab := _button((AVATAR_FROM_X + AVATAR_TO_X + AVATAR_W) * 0.5, ACTION_Y, WIDE_BUTTON_TEXTURE)
	_action_button = ab[0]
	_action_label = ab[1]
	_action_button.pressed.connect(_on_action_pressed)

	# A dialog over the world, not a full-screen panel - so the round X in the
	# corner rather than the bottom-right back arrow. See CloseButton.
	CloseButton.add_to(self, BOARD_SIZE, hide)


func _frame(fx: float) -> TextureRect:
	var t := TextureRect.new()
	# Before size, or the art's own dimensions become the minimum and the frame
	# refuses to shrink - the trap every panel in this project has hit.
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = _px(fx, SLOT_Y)
	t.size = _px(SLOT_W, SLOT_H)
	_content.add_child(t)
	return t


# Inset from the frame so the art sits inside the recess rather than over its
# moulding.
func _preview(fx: float, inset: float) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = _px(fx + inset, SLOT_Y + 0.07)
	t.size = _px(SLOT_W - inset * 2.0, SLOT_H - 0.14)
	_content.add_child(t)
	return t


# fx is the button's CENTRE, and the width comes from the texture's own aspect
# at the shared height - so both sizes keep their proportions and neither is
# squashed to fit a column.
#
# The caption is a child OF the button, not a sibling. As a sibling it was
# parented to _content, which is added before the buttons are, so every button
# drew its art straight over its own label - three blank orange pills.
func _button(fx: float, fy: float, texture: Texture2D) -> Array:
	# 1x NATIVE: the button art is @2x, so half its pixels is its intended size.
	var h: float = texture.get_height() * 0.5
	var w: float = texture.get_width() * 0.5
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = texture
	b.size = Vector2(w, h)
	b.position = Vector2(BOARD_SIZE.x * fx - w * 0.5, BOARD_SIZE.y * fy)
	add_child(b)

	var l := Label.new()
	l.add_theme_font_size_override("font_size", _fs(FONT_BUTTON))
	l.add_theme_color_override("font_color", Color(0.26, 0.13, 0.02, 1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.anchor_right = 1.0
	l.anchor_bottom = 1.0
	# Shrink rather than overflow: "Refuel & Return" has to fit the same pill
	# "Skin" does.
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.add_child(l)
	return [b, l]


func _avatar_tile(fx: float) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = AVATAR_FRAME
	t.position = _px(fx, AVATAR_Y)
	t.size = _px(AVATAR_W, AVATAR_H)
	_content.add_child(t)
	return t


# The face inside the tile, inset so it sits within the frame's border.
func _avatar_art(fx: float) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.position = _px(fx + 0.012, AVATAR_Y + 0.05)
	t.size = _px(AVATAR_W - 0.024, AVATAR_H - 0.10)
	_content.add_child(t)
	return t


func _label(size_px: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l


# Fires whenever the panel opens on a pad or closes. The in-transit countdown
# only shows on the pad whose menu is up, and without this nothing tells the
# slots to look again - opening the menu changed no game state, so no signal
# they were listening to fired and the bubble never appeared.
signal shown_apron_changed(apron_id: int)


# Which pad this panel is currently open on, or -1. The in-transit countdown
# only shows for the pad whose menu is open (see ApronSlot), so the slots need
# to be able to ask.
func showing_apron_id() -> int:
	return _apron_id if visible else -1


func show_apron(apron: Apron) -> void:
	_apron_id = apron.id
	_apron = apron
	move_to_front()
	visible = true
	_refresh()
	shown_apron_changed.emit(_apron_id)


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func _set_action(text: String, enabled: bool) -> void:
	_action_button.visible = true
	_action_label.visible = true
	_action_label.text = text
	_action_button.disabled = not enabled
	_action_button.modulate = Color.WHITE if enabled else DISABLED_MODULATE


func _hide_action() -> void:
	_action_button.visible = false
	_action_label.visible = false


func _set_slots_visible(on: bool) -> void:
	for n in [_plane_frame, _plane_icon, _skin_frame, _skin_preview,
			_plane_button, _plane_label, _skin_button, _skin_label,
			_from_frame, _from_avatar, _to_frame, _to_avatar]:
		n.visible = on


# The destination tile: the friend you fly to, or the blue "?" when this pad
# has no route yet.
func _refresh_route_preview(a: FleetAircraft) -> void:
	if a == null:
		_to_avatar.texture = AVATAR_NONE
		return
	var info: Dictionary = Friends.info_for(Fleet.destination_of(a))
	var path := str(info.get("avatar", ""))
	_to_avatar.texture = load(path) if (path != "" and ResourceLoader.exists(path)) else AVATAR_NONE


func _refresh(_unused = null) -> void:
	if not visible or _apron_id == -1:
		return
	_title.text = "Apron %d" % _apron_id

	# _apron.built was correct as of show_apron() and stays valid if it was
	# already true then (built never reverts) - but it won't pick up a build
	# that happens while this panel is open, so OR it with a live check.
	if not (_apron and (_apron.built or ApronProgress.is_built(_apron_id))):
		_set_slots_visible(false)
		# A locked zone is bought whole in the expansion shop, so there is no
		# per-apron action to offer here at all.
		if not ZoneProgress.is_unlocked(_apron.area_name):
			_status.text = "Locked"
			_hide_action()
			return
		var cost := ApronProgress.cost_for_area(_apron.area_name)
		_status.text = ""
		_set_action("Build ($%d)" % cost, Economy.money >= cost)
		return

	_set_slots_visible(true)
	# The robot airport is somewhere you visit. Its pads aren't yours to skin
	# any more than they're yours to assign to.
	var at_robot := Maps.is_robot_map()
	_skin_frame.visible = not at_robot
	_skin_preview.visible = not at_robot
	_skin_button.visible = not at_robot
	_skin_label.visible = not at_robot
	if not at_robot:
		_refresh_skin_slot()

	# WHICH PAD THIS IS DECIDES WHICH FIELD TO ASK ABOUT. get_aircraft_at_apron
	# matches on assigned_apron_id, which is the aircraft's pad at YOUR
	# airport; at a friend's it stands on robot_apron_id and that lookup found
	# nothing, so every pad over there read as empty however full it was.
	#
	# The HOLDER is asked for rather than what is physically standing there, so
	# the pad shows its aircraft through the whole route - counting down on the
	# way in, and still its pad on the way back - exactly as the home pad does.
	var a := (Fleet.get_aircraft_holding_robot_apron(_apron_id) if at_robot
		else Fleet.get_aircraft_at_apron(_apron_id))
	_refresh_plane_slot(a)
	_refresh_route_preview(a)

	# ONE job: the route. Fuelling, departing, claiming and refuelling were all
	# offered here too, and every one of them already had two other homes - the
	# pad's own bubble (ApronSlot._set_callout_icon) and the routes table, which
	# additionally does the whole fleet at once. A third copy on the panel you
	# reach by clicking the aircraft was the least convenient of the three and
	# the only one that pushed the route screen out - it owned the single button
	# this panel has room for, so an occupied pad had no way back to its route.
	#
	# What this panel is for is the things nothing else offers: change the
	# destination, change the aircraft, delete the route. All three live in
	# RoutePickerPanel, so the button opens it and the status line stays as
	# information - a word or a clock, never an action.
	if Maps.is_robot_map():
		# Someone else's airport. The aircraft here is mid-trip on a route set
		# at home, and its bubble is how you claim and refuel it.
		_hide_action()
	else:
		_set_action("Manage Route" if a else "Create Route", true)

	if not a:
		_status.text = "\u2192"
		return

	var dest := Fleet.destination_of(a)
	match a.state:
		FleetAircraft.State.PARKED:
			# Out of range is a dead end rather than a wait, and the fix for it
			# is in the route screen the button now opens.
			_status.text = ("%d ~" % Fleet.distance_to(dest)
				if not Fleet.in_range(a.model_key, dest) else "\u2192")
		FleetAircraft.State.FLYING_OUT, FleetAircraft.State.FLYING_BACK:
			_status.text = _countdown(a.flight_time_left)
		FleetAircraft.State.AWAITING_DEST_CLAIM:
			_status.text = "Arrived"
		FleetAircraft.State.AWAITING_DEST_REFUEL:
			_status.text = "Claimed"
		FleetAircraft.State.AWAITING_HOME_CLAIM:
			_status.text = "Landed"
		FleetAircraft.State.AWAITING_HOME_REFUEL:
			_status.text = "Refuel"


# Legs run to hours at the far destinations, so a bare seconds count would read
# "42107s" - see Fleet.CLOUD_BASE_MINUTES.
func _countdown(secs: float) -> String:
	var t := int(ceilf(secs))
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm %02ds" % [t / 60, t % 60]
	return "%ds" % t


func _refresh_skin_slot() -> void:
	var entry := ApronSkins.get_skin_entry(_apron_id)
	if entry.size() > 0:
		_skin_frame.texture = SKIN_FRAME_FILLED
		_skin_preview.texture = load(entry["texture"])
		_skin_preview.visible = true
		_skin_label.text = "Liveries"
	else:
		_skin_frame.texture = SKIN_FRAME_EMPTY
		_skin_preview.visible = false
		_skin_label.text = "Liveries"


func _refresh_plane_slot(a: FleetAircraft) -> void:
	_plane_frame.texture = PLANE_FRAME_FILLED if a else PLANE_FRAME_EMPTY
	_plane_icon.visible = a != null
	if a:
		# The PAINTED hull when this aircraft wears a livery, not the model's
		# shop icon - otherwise the slot right next to the Liveries button is
		# the one picture in the game that never reflects the livery you just
		# bought, which reads as the purchase having done nothing.
		var path := ""
		if a.livery != "":
			var liv := AircraftSkins.entry(a.model_key, a.livery)
			path = str(liv.get("body", ""))
		if path == "":
			var e := ShopCatalog.entry_for(a.model_key)
			if e.has("icon"):
				path = "res://assets/shop/%s" % e["icon"]
		if path != "" and ResourceLoader.exists(path):
			_plane_icon.texture = load(path)

	# The robot airport is somewhere you visit, not somewhere you base aircraft.
	if Maps.is_robot_map():
		_plane_label.text = "Visiting"
		_plane_button.disabled = true
		_plane_button.modulate = DISABLED_MODULATE
		return
	# Liveries exist only for the models we have alternate hull art for, and
	# only for an aircraft actually standing here.
	_plane_label.text = "Liveries"
	_plane_button.disabled = a == null or not AircraftSkins.has_any(a.model_key)
	_plane_button.modulate = DISABLED_MODULATE if _plane_button.disabled else Color.WHITE


func _on_skin_button_pressed() -> void:
	get_node("../SkinPickerPanel").show_for_apron(_apron_id)


# The plane slot's button paints the aircraft standing on this pad: liveries
# are bought per aircraft and buy a speed grade (see AircraftSkins).
func _on_plane_button_pressed() -> void:
	var a := (Fleet.get_aircraft_at_robot_apron(_apron_id) if Maps.is_robot_map()
		else Fleet.get_aircraft_at_apron(_apron_id))
	if a:
		get_node("../LiveryPickerPanel").show_for_aircraft(a.id)


# Build the pad if it isn't built; otherwise the route screen, which is the
# only thing this panel offers that is not already offered somewhere better.
func _on_action_pressed() -> void:
	if not (_apron and (_apron.built or ApronProgress.is_built(_apron_id))):
		ApronProgress.build(_apron_id, _apron.area_name)
		return
	get_node("../RoutePickerPanel").show_for_apron(_apron_id)
