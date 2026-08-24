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
const NAME_Y := 0.545
const SUB_Y := 0.610
const STAT_Y := 0.665
const DETAIL_Y := 0.30
const DETAIL_STEP := 0.078
# Buttons sit lower and the type above them sits higher - the two were both at
# 0.72 and the column read as one crowded block. See _clear_button for where
# the destructive one went.
const ACTION_Y := 0.70
# Delete sits BELOW the action row and smaller, under the aircraft column. It
# was at the bottom-left corner at full size, where it overlapped "Change
# aircraft" by 120px and, being added later, swallowed its clicks - and both
# reason labels were positioned off the bottom of the 430px board entirely.
const CLEAR_X := 0.162
const CLEAR_Y := 0.86
# Reasons go under the ACTION column only, where there is room for them.
const REASON_Y := 0.855

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
# Same grey ApronInfoPanel uses for a button you can see but can't press.
const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 1)

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
	# An aircraft already on the pad keeps its own route; an empty pad has no
	# aircraft to size a default against yet, so it takes the nearest and gets
	# re-defaulted the moment one is chosen - see _on_hangar_picked.
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


# Hands over to the friends list and comes back with the answer - the same
# arrangement the aircraft column has with the hangar, and for the same reason:
# that screen already draws the options as cards, at a size you can read, with
# their avatar and level on them.
#
# This replaced cycling the destination by clicking the middle column. With one
# destination that read as a dead label; with five it is a guessing game whose
# only way to see the options is to click through all of them.
func _open_friend_chooser() -> void:
	hide()
	get_node("../FriendsPanel").open_for_selection(_on_friend_picked)


func _on_friend_picked(map_key: String) -> void:
	# "" means the list was closed without choosing - keep the destination that
	# was already set rather than clearing it, but come back either way, or the
	# route screen stays hidden behind a panel the player thinks they dismissed.
	if map_key != "":
		_destination = map_key
	move_to_front()
	visible = true
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


func _aircraft_column(a: FleetAircraft) -> void:
	var entry := ShopCatalog.entry_for(a.model_key)
	_clouds(int(ShopCatalog.stat(a.model_key, "range")), COL_X[0])
	if entry.has("icon"):
		var art := TextureRect.new()
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		# Painted hull if it wears one - see ApronInfoPanel._refresh_plane_slot.
		var art_path := ""
		if a.livery != "":
			art_path = str(AircraftSkins.entry(a.model_key, a.livery).get("body", ""))
		if art_path == "" or not ResourceLoader.exists(art_path):
			art_path = "res://assets/shop/%s" % entry["icon"]
		art.texture = load(art_path)
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
	var current := Fleet.get_aircraft(_aircraft_id)
	# Scaled to the BOARD, not to the art's pixels - this board is drawn at
	# 1.20x of its own art, so a fixed pixel size reads small on it. See
	# FriendInfoPanel for the measurement.
	var native := _button_size(CONFIRM_TEXTURE)
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = CONFIRM_TEXTURE
	b.custom_minimum_size = native
	b.size = native
	b.position = Vector2(BOARD_SIZE.x * COL_X[0] - native.x * 0.5, BOARD_SIZE.y * ACTION_Y)
	b.pressed.connect(_open_hangar_chooser)
	_content.add_child(b)
	# Taking a machine off a pad it is actively using is not the same as
	# re-aiming its route, and stays blocked while it is away.
	if current and not _can_change_aircraft(current):
		b.disabled = true
		b.modulate = DISABLED_MODULATE
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
			# Point it at the destination matching its rating unless it is
			# already routed somewhere. A rating-5 flagship defaulting to the
			# 1-cloud robot earns a fifth of what it should, and the player has
			# to notice and fix that by hand on every single purchase.
			if a.destination == "":
				_destination = Fleet.best_destination_for(model_key)
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

	_friend_button()

	# UNSAVED CHANGES ARE INVISIBLE OTHERWISE. Choosing a friend only sets what
	# the panel is showing; nothing reaches the aircraft until Update route is
	# pressed. So the flow was: pick a destination, come back to a panel that
	# looks exactly as it did, close it - and the change is silently gone. That
	# reads as "you cannot change the destination", which is what it amounts to.
	var a := Fleet.get_aircraft(_aircraft_id)
	if a and a.assigned_apron_id == _apron_id and _destination != Fleet.destination_of(a):
		var warn := _label("unsaved - press Update route", _fs(FONT_SUB))
		warn.position = Vector2(BOARD_SIZE.x * (COL_X[1] - 0.15), BOARD_SIZE.y * STAT_Y)
		warn.size = Vector2(BOARD_SIZE.x * 0.30, BOARD_SIZE.y * 0.09)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		warn.add_theme_color_override("font_color", Color(1.0, 0.86, 0.45))
		_content.add_child(warn)


# Under the destination column, matching the aircraft column's chooser exactly:
# same art, same place, same "this is a thing you change" reading.
func _friend_button() -> void:
	var native := _button_size(CONFIRM_TEXTURE)
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = CONFIRM_TEXTURE
	b.custom_minimum_size = native
	b.size = native
	b.position = Vector2(BOARD_SIZE.x * COL_X[1] - native.x * 0.5, BOARD_SIZE.y * ACTION_Y)
	b.pressed.connect(_open_friend_chooser)
	_content.add_child(b)

	# Says how many there are to choose from, because with one unlocked the
	# screen it opens has a single card on it and that needs to read as a gate
	# rather than as a broken list.
	var n := Friends.list().size()
	var text := "Choose friend (%d)" % n if n > 1 else "Choose friend"
	var l := _label(text, _fitted_font(text, native.x - ACTION_PADDING), true)
	l.size = native
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)


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

	# The two cloud rows above already carry it - the aircraft's rating on the
	# left, the route's in the middle - but that is a comparison the player has
	# to make, and the refusal itself happens later and elsewhere (the pad's
	# depart bubble just does nothing). With five destinations to choose
	# between, that is a trap, so the verdict is stated here.
	if not Fleet.in_range(a.model_key, dest):
		var warn := _label("Out of range - needs %d clouds"
			% Fleet.distance_to(dest), _fs(FONT_DETAIL), true)
		warn.add_theme_color_override("font_color", Color(1.0, 0.45, 0.36))
		warn.position = Vector2(BOARD_SIZE.x * 0.655,
			BOARD_SIZE.y * (DETAIL_Y + rows.size() * DETAIL_STEP))
		warn.size = Vector2(BOARD_SIZE.x * 0.32, BOARD_SIZE.y * 0.07)
		warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_content.add_child(warn)

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


# APPLY, and separately CLEAR. These used to be one button that swapped
# meaning: a pad with an aircraft on it offered only "Delete", so the sole way
# to fly somewhere else - or to swap the aircraft - was to tear the route down
# and build it again from an empty pad. Changing your mind is the ordinary case,
# not the exceptional one, so applying is now the primary button and deleting is
# a separate, deliberately distant one.
func _action_button(a: FleetAircraft) -> void:
	var assigned := a.assigned_apron_id == _apron_id
	var native := _button_size(CONFIRM_TEXTURE)
	# Says which of the two it will do, because with an aircraft in the air the
	# destination applies from its NEXT departure rather than right now.
	# Says there is something to save, so the button reads as the commit step
	# rather than as a no-op you can skip.
	var pending := assigned and _destination != Fleet.destination_of(a)
	var text := "Set route"
	if assigned:
		text = "Update route *" if pending else "Update route"

	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = CONFIRM_TEXTURE
	b.custom_minimum_size = native
	b.size = native
	b.position = Vector2(BOARD_SIZE.x * COL_X[2] - native.x * 0.5, BOARD_SIZE.y * ACTION_Y)
	b.pressed.connect(_on_confirm)
	_content.add_child(b)

	# A route can only be re-pointed while its aircraft is standing on the pad.
	# Re-aiming one mid-flight would teleport it, and swapping the aircraft
	# under a live route would strand the one that is actually out there.
	if not _can_edit_route(a):
		b.disabled = true
		b.modulate = DISABLED_MODULATE
		_reason_under(_blocked_reason(a), COL_X[2], REASON_Y)

	var l := _label(text, _fitted_font(text, native.x - ACTION_PADDING), true)
	l.size = native
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)

	if assigned:
		_clear_button(a)


# Bottom-left, away from everything else on the board. A destructive button
# under the same finger as the one you press every time is how routes get
# deleted by accident.
func _clear_button(a: FleetAircraft) -> void:
	var native := _button_size(CLEAR_NORMAL)
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = CLEAR_NORMAL
	b.texture_pressed = CLEAR_PRESSED
	b.texture_hover = CLEAR_PRESSED
	b.custom_minimum_size = native
	b.size = native
	b.position = Vector2(BOARD_SIZE.x * CLEAR_X - native.x * 0.5, BOARD_SIZE.y * CLEAR_Y)
	b.pressed.connect(_on_clear)
	_content.add_child(b)

	if not _can_clear(a):
		b.disabled = true
		b.modulate = DISABLED_MODULATE

	var l := _label("Delete", _fitted_font("Delete", native.x - ACTION_PADDING), true)
	l.size = native
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	b.add_child(l)


func _reason_under(text: String, cx: float, y: float) -> void:
	var why := _label(text, _fs(FONT_SUB))
	why.position = Vector2(BOARD_SIZE.x * (cx - 0.15), BOARD_SIZE.y * y + 2.0)
	why.size = Vector2(BOARD_SIZE.x * 0.30, BOARD_SIZE.y * 0.09)
	why.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	why.add_theme_color_override("font_color", Color(1.0, 0.72, 0.6))
	_content.add_child(why)


func _away(a: FleetAircraft) -> bool:
	return a.state in [FleetAircraft.State.FLYING_OUT, FleetAircraft.State.FLYING_BACK,
		FleetAircraft.State.AWAITING_DEST_CLAIM, FleetAircraft.State.AWAITING_DEST_REFUEL]


# A PARKED aircraft can be re-pointed freely; one that is away cannot, because
# its pay and its return clock are both read off the destination while the trip
# is in progress. Re-aiming mid-flight would rewrite a journey already made.
func _can_edit_route(a: FleetAircraft) -> bool:
	return a.assigned_apron_id != _apron_id or not _away(a)


func _can_change_aircraft(a: FleetAircraft) -> bool:
	return a.assigned_apron_id != _apron_id or not _away(a)


func _can_clear(a: FleetAircraft) -> bool:
	return not _away(a)


# Collect and refuel an aircraft that has come home, leaving it PARKED. Shared
# by both buttons: finishing a trip is bookkeeping, not a decision, and making
# the player do it by hand before they are allowed to change anything was three
# taps to express nothing. Refuelling can still fail for want of fuel, which
# leaves it mid-tidy - callers check the state afterwards.
func _settle(a: FleetAircraft) -> void:
	if a.assigned_apron_id != _apron_id:
		return
	if a.state == FleetAircraft.State.AWAITING_HOME_CLAIM:
		Fleet.claim_home_reward(a.id)
	if a.state == FleetAircraft.State.AWAITING_HOME_REFUEL:
		Fleet.park_at_home(a.id)


# What the player has to do about it - "not parked" is a state name, not an
# instruction.
func _blocked_reason(a: FleetAircraft) -> String:
	match a.state:
		FleetAircraft.State.FLYING_OUT, FleetAircraft.State.FLYING_BACK:
			return "in the air - wait for it to land"
		FleetAircraft.State.AWAITING_DEST_CLAIM, FleetAircraft.State.AWAITING_DEST_REFUEL:
			return "still at the destination"
		_:
			return "land it first"


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
	if not a or not _can_edit_route(a):
		return
	# TIDY UP A FINISHED TRIP FIRST - the same thing Delete does, and for the
	# same reason. An aircraft that has landed sits in AWAITING_HOME_CLAIM: home,
	# but not parked. Re-pointing it without claiming left the reward
	# uncollected and the tank empty, so the route you had just set could not
	# depart - and only Delete cleaned that up, which is why changing a
	# destination appeared to require deleting the route first.
	#
	# Claiming BEFORE the destination changes also pays the trip that was
	# actually flown, rather than the fare of wherever it is being re-aimed at.
	_settle(a)
	# SWAPPING LEAVES THE OLD ONE HOLDING THE PAD otherwise - assign_to_apron
	# only sets the incoming aircraft's id, so both would claim apron 5 and both
	# would draw on it. Unreachable while the only way to change an aircraft was
	# to delete the route first; reachable the moment "Update route" stopped
	# requiring that.
	var sitting := Fleet.get_aircraft_at_apron(_apron_id)
	if sitting and sitting.id != a.id:
		# Swapping is the part that needs it home; re-pointing is not.
		if not _can_change_aircraft(sitting):
			return
		# SETTLE THE ONE BEING REPLACED, not just the one arriving. _settle(a)
		# above is a no-op when swapping - `a` is the incoming aircraft and its
		# assigned_apron_id is -1, not this pad - so the machine actually
		# standing here was never tidied up. An aircraft that has just landed
		# sits in AWAITING_HOME_CLAIM rather than PARKED, which is the normal
		# state of one you have flown, and the check below then returned
		# SILENTLY: press Set route, nothing happens, no reason given, forever.
		_settle(sitting)
		if sitting.state != FleetAircraft.State.PARKED:
			return
		Fleet.unassign(sitting.id)
	a.destination = _destination
	Fleet.assign_to_apron(a.id, _apron_id)
	Fleet.fleet_changed.emit()
	hide()


# Deleting a route on an aircraft that has come home now CLAIMS AND REFUELS it
# first. Making the player collect the money, then refuel, and only then be
# allowed to delete was three taps of bookkeeping to express one decision - and
# the reward is theirs either way; the route being over does not forfeit it.
func _on_clear() -> void:
	var a := Fleet.get_aircraft(_aircraft_id)
	if a == null:
		hide()
		return
	if not _can_clear(a):
		return
	_settle(a)
	# Refuelling can fail for want of fuel, which leaves it mid-tidy rather
	# than parked. Say so instead of closing on a route that is still there.
	if a.state != FleetAircraft.State.PARKED:
		_rebuild()
		return
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


# One button width for this board: a tenth of it, which is the ratio the
# changelist panels already use. Height follows the art's own aspect.
func _button_size(art: Texture2D) -> Vector2:
	var w: float = BOARD_SIZE.x * 0.10
	return Vector2(w, w * art.get_height() / float(art.get_width()))
