extends PanelContainer

# Every aircraft currently in service, as a table: what it is, where it's gone,
# how long it has left, and one button that does whatever that aircraft needs
# next.
#
# The point of the single button is remoteness. Each of these actions already
# exists as a bubble on an apron, but the destination ones are at the robot's
# airport - so without this you'd have to fly over, claim, refuel, and come
# back for every aircraft. Here the whole loop is driveable from home.
const ROW_BOARD := preload("res://assets/board/board_aircraft_list@2x.png")
# The wide variant, for the one button whose label doesn't fit the short one.
const WIDE_ACTION_TEXTURE := preload("res://assets/buttons/button_orange4@2x.png")
const COUNT_BOARD_TEXTURE := preload("res://assets/board/board_airline4@2x.png")

const COUNT_BOARD_SIZE := Vector2(410, 62)
const BOARD_RIGHT_MARGIN := 20.0
const BOARD_TOP_MARGIN := 24.0

# Narrower than the panel on purpose: the back arrow occupies the bottom-right
# corner of a 1152-wide panel, its left edge at x1078, and a row wide enough to
# reach it would run straight through. Plus room for the scrollbar.
#
# 964, up from 900. The row area is centred in the 1056 the margins leave, so a
# row of width W has its right edge at 576 + (W + SCROLLBAR_ALLOWANCE) / 2:
# 964 puts it at 1065, thirteen clear of the arrow, and 980 - the width tried
# once before - puts it at 1073.
const ROW_SIZE := Vector2(964, 52)
const SCROLLBAR_ALLOWANCE := 14.0
const ICON_SIZE := Vector2(44, 44)
# Half the row's height, so a line reads as exactly two buttons tall. The
# button art is natively 136x62; drawn at half height it needs a smaller label
# to match, hence ACTION_FONT being well under the row's own font size.
#
# The row was 62 tall. It is 52 now, along with everything sized off it, to fit
# more of the fleet on screen at once - a 62px row put six lines in the scroll
# area at a point in the game where the fleet is sixty aircraft.
# THE VISIBLE BUTTON IS NOT THIS WIDE. The art is drawn KEEP_ASPECT_CENTERED,
# so it fits by the SHORT side and the rest of the box is empty: the narrow art
# (136x62) at 26 high painted 57px of button inside a 112px rect, which is why a
# nine-character caption spilled out of a button that looked twice wide enough.
#
# The wide art at 30 high paints 93px, and "Turn around" measures 73 at font 12
# - so it fits with ten pixels either side, which is the whole reason for both
# numbers. The row has 148px between COL_ACTION and its right edge.
const ACTION_SIZE := Vector2(130, 30)
const ACTION_FONT := 12
# Column x positions inside a row. The icon and the type stay where they were -
# a left-anchored column that moves for no reason only makes two versions of the
# panel harder to compare - and the 64 pixels the wider row brings go to the
# three columns right of them, which were the tight ones. COL_ACTION keeps the
# same 148px to the row's right edge that the button was sized against.
const COL_ICON := 10.0
const COL_TYPE := 84.0
const COL_DEST := 356.0
const COL_TIME := 600.0
const COL_ACTION := 816.0

# THE SAME TWO SECONDS THE APRONS SPEND. Collecting from this list was instant
# while the identical action on a pad played a swoop - so the fast way to run an
# airport was to stop looking at it, which is the opposite of what the swoop
# exists for (see ProgressBubble: an airport should be seen WORKING, not only
# finishing).
#
# THE PROGRESS LIVES IN THE PANEL, NOT THE ROW. _refresh frees and rebuilds
# every row, and it runs on fleet_changed - which fires whenever any aircraft
# anywhere lands, claims or departs. A bubble parented to a row would be
# destroyed part-filled by an unrelated aircraft touching down, which is
# precisely the bug ApronLayer documents. Keyed by aircraft id here, so a
# rebuild redraws it at the fill it had reached.
const SWOOP_SECONDS := 2.0
# Sized to the button it replaces, so the row does not change shape mid-swoop.
const SWOOP_BAR_SIZE := Vector2(96, 10)
# ProgressBubble's own bar colours, so a claim reads the same here as on a pad.
const SWOOP_TRACK := Color(0.16, 0.16, 0.18, 0.75)
const SWOOP_EARN_COLOR := Color(0.47, 0.86, 0.51)
const SWOOP_FUEL_COLOR := Color(0.94, 0.71, 0.24)

# Which actions are refuelling, for the bubble art and the bar colour.
const FUEL_STATES := [
	FleetAircraft.State.PARKED,
	FleetAircraft.State.AWAITING_DEST_REFUEL,
	FleetAircraft.State.AWAITING_HOME_REFUEL,
]
const ROW_FONT := 15

# The bulk control. A round trip is five presses per aircraft, so a fleet of
# five costs twenty-five to go round once - this does the lot in one.
#
# Drawn at button_orange4's ASPECT, 192x62, rather than its native size: 138x45
# is the same 3.1:1 so the art is not squashed, and the 17px it gives back go to
# the row area. It was the full 192x62, which is a lot of furniture under a list
# that wanted the space more. It used to be the 136x62 button pulled out to
# 300x46 - stretched 2.2x wide and squashed to three quarters height, which read
# as exactly what it was; the wide art exists for this.
# LOCKED UNTIL LEVEL 15. Measured rather than picked: the manual turnaround
# costs two taps an aircraft and this button costs two flat, so what it saves is
# 2N-2, and the bot puts the fleet at 5-10 aircraft by level 8 - under 18 taps,
# which nobody would miss - and at 20 by level 15, where it saves 38 taps, about
# 46 seconds of tapping every cycle. So the unlock lands where the tedium starts
# rather than before it.
#
# The bot also buys optimally, holding more aircraft at a given level than a
# person does, which means a level read off its table arrives early rather than
# late - the safe direction.
#
# Level 15 already carries the TV Tower and the Dash 8; 14 is empty if this
# wants a moment of its own.
const DEPART_ALL_LEVEL := 15
const LOCKED_TEXTURE := preload("res://assets/buttons/button_grey3@2x.png")

# 1x NATIVE. Was 138x45 - double width, and an aspect of 3.07 against art drawn
# at 2.19, so it was stretched as well as oversized.
# THE WIDE ART'S 1x. button_orange4 is 192x62 @2x, so 96x31 - not the pill's
# 68x31, which is what this was and it cropped "Depart all". The wide button is
# what a caption too long for the pill is for.
const RUN_ALL_SIZE := Vector2(96, 31)
const RUN_ALL_FONT := 15
const RESULT_FONT := 15
const RESULT_HOLD := 3.0

# ONE LINE OF CHROME, NOT THREE. The title, the sort buttons and Depart all
# each had a row to themselves, stacked down the middle of a panel 1056 wide -
# 131 of the content area's 340 pixels spent on three short lines, each with the
# whole width to the right of it empty. They share a line now and the table gets
# those pixels: about two more aircraft on screen.
#
# The two side cells are given the SAME minimum width, so the sort group lands
# on the row's true centre and therefore on the table's, which is centred in the
# same space. Left to find their own widths - the title is about 90 wide and the
# Depart all cell about 320 - the group would sit some 150 pixels left of
# centre, which reads as a mistake rather than as a layout.
const HEADER_SIDE := 320.0

enum Sort { TYPE, TIME, COMPLETED }

const SORTS := [
	{"sort": Sort.TYPE, "label": "Type"},
	{"sort": Sort.TIME, "label": "Time left"},
	{"sort": Sort.COMPLETED, "label": "Ready"},
]

# What each state needs next, and what to call it. FLYING_* are absent on
# purpose: an aircraft in the air has nothing you can do for it.
const ACTIONS := {
	FleetAircraft.State.PARKED: "Depart",
	FleetAircraft.State.AWAITING_DEST_CLAIM: "Turn around",
	# "Send home" was the caption that exposed the sizing above - it overflowed
	# a button that measured 112 and painted 57. "Return" says the same thing
	# and is shorter, and is kept now the button is wide enough for either.
	FleetAircraft.State.AWAITING_DEST_REFUEL: "Return",
	FleetAircraft.State.AWAITING_HOME_CLAIM: "Turn around",
	FleetAircraft.State.AWAITING_HOME_REFUEL: "Refuel",
}

@onready var _grid: GridContainer = $Frame/SafeArea/Margin/VBox/Grid
var _scroll: ScrollContainer
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton
@onready var _vbox: VBoxContainer = $Frame/SafeArea/Margin/VBox
@onready var _frame: Control = $Frame

var _sort: int = Sort.TIME
var _count_label: Label
var _empty_label: Label
var _sort_buttons: Dictionary = {}
var _run_all: TextureButton
var _run_all_label: Label
var _result_label: Label
# aircraft id -> seconds elapsed on its swoop.
var _swoops := {}
# aircraft id -> the bubble showing it, so the bar can be advanced without
# rebuilding the row sixty times a second.
var _swoop_nodes := {}
var _result_timer := 0.0

# aircraft id -> tap sequence number. What sends a tapped row to the back of
# the queue, and what keeps it there until the aircraft has nothing left to do.
var _tap_order: Dictionary = {}
var _tap_seq := 0


func _ready() -> void:
	_close_button.pressed.connect(hide)
	Progression.level_changed.connect(func(_n = null) -> void: _refresh_run_all())
	# The reference uses a bottom-right arrow, not a full-width bar.
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	Fleet.fleet_changed.connect(_on_fleet_changed)
	get_tree().root.size_changed.connect(_fit_content)
	_build_count_board()
	_build_header_row()
	_build_empty_label()
	_make_scrollable()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh()
		call_deferred("_fit_content")


func _on_fleet_changed(_unused = null) -> void:
	if visible:
		_refresh()


# Times tick down every frame, so the rows would go stale sitting open. Only
# the labels are rewritten - rebuilding the rows would fight the buttons.
func _process(delta: float) -> void:
	# Swoops run even while the panel is closed: an action already paid for
	# should not be cancelled by looking away, and _refresh is guarded on
	# visible anyway.
	_tick_swoops(delta)
	if not visible:
		return
	if _result_timer > 0.0:
		_result_timer -= delta
		if _result_timer <= 0.0 and is_instance_valid(_result_label):
			_result_label.text = ""
	for row in _grid.get_children():
		var a := Fleet.get_aircraft(int(row.get_meta("aircraft_id", -1)))
		if a:
			(row.get_meta("time_label") as Label).text = _time_text(a)


func _fit_content() -> void:
	var vbox: Control = $Frame/SafeArea/Margin/VBox
	var safe_area: Control = $Frame/SafeArea
	if not is_instance_valid(vbox) or not is_instance_valid(safe_area):
		return
	vbox.scale = Vector2.ONE
	var natural := vbox.get_combined_minimum_size()
	var available := safe_area.size
	if natural.x <= 0 or natural.y <= 0 or available.x <= 0 or available.y <= 0:
		return
	var s := minf(1.0, minf(available.x / natural.x, available.y / natural.y))
	vbox.scale = Vector2(s, s)


# A fleet of any size overruns the panel: twelve aircraft need ~900px of rows
# inside a ~345px area. _fit_content's shrink-to-fit is the wrong tool here -
# at that count it would scale the table to 38% and make it unreadable - so the
# grid goes in a ScrollContainer and keeps its real size instead.
func _make_scrollable() -> void:
	var parent := _grid.get_parent()
	var at := _grid.get_index()
	parent.remove_child(_grid)

	_scroll = ScrollContainer.new()
	_scroll.name = "RowScroll"
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_scroll.custom_minimum_size = Vector2(ROW_SIZE.x + SCROLLBAR_ALLOWANCE, 0)
	parent.add_child(_scroll)
	parent.move_child(_scroll, at)

	# The grid must not expand vertically inside the scroller, or it stretches
	# to the viewport instead of overflowing it - and then nothing scrolls.
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_scroll.add_child(_grid)


# --- chrome --------------------------------------------------------------

func _build_count_board() -> void:
	var wrap := Control.new()
	wrap.name = "CountBoard"
	wrap.anchor_left = 1.0
	wrap.anchor_right = 1.0
	wrap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	wrap.offset_left = -(COUNT_BOARD_SIZE.x + BOARD_RIGHT_MARGIN)
	wrap.offset_right = -BOARD_RIGHT_MARGIN
	wrap.offset_top = BOARD_TOP_MARGIN
	wrap.offset_bottom = BOARD_TOP_MARGIN + COUNT_BOARD_SIZE.y
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var board := TextureRect.new()
	board.texture = COUNT_BOARD_TEXTURE
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(board)

	_count_label = Label.new()
	_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 21)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_outline_color", Color(0.11, 0.06, 0.02, 1))
	_count_label.add_theme_constant_override("outline_size", 6)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_count_label)

	_frame.add_child(wrap)


# Title left, sort in the middle, Depart all right - the three rows of chrome
# this panel used to stack, on one line. See HEADER_SIDE for why the outer two
# carry a minimum width.
func _build_header_row() -> void:
	var row := HBoxContainer.new()
	row.name = "Header"
	row.add_theme_constant_override("separation", 10)

	# The scene's own title, MOVED rather than restated, so its font and text
	# stay the one the panel was authored with.
	var title: Label = $Frame/SafeArea/Margin/VBox/TitleLabel
	_vbox.remove_child(title)
	title.custom_minimum_size = Vector2(HEADER_SIDE, 0)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	var middle := _build_sort_group()
	middle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(middle)

	var right := _build_run_all_group()
	right.custom_minimum_size = Vector2(HEADER_SIDE, 0)
	row.add_child(right)

	_vbox.add_child(row)
	_vbox.move_child(row, _grid.get_index())


func _build_sort_group() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var heading := Label.new()
	heading.text = "Sort by"
	heading.add_theme_font_size_override("font_size", 16)
	heading.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	row.add_child(heading)

	var group := ButtonGroup.new()
	for entry in SORTS:
		var b := Button.new()
		b.text = entry["label"]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = entry["sort"] == _sort
		b.pressed.connect(_on_sort_pressed.bind(entry["sort"]))
		row.add_child(b)
		_sort_buttons[entry["sort"]] = b
	return row


func _build_run_all_group() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 14)

	# The readout takes whatever the button leaves and reads back towards it, so
	# a long result grows leftward into empty row instead of pushing the button
	# off the end. It used to need a spacer of its own width on the far side to
	# stop exactly that; the fixed-width cell does that job now.
	_result_label = Label.new()
	_result_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_result_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_result_label.clip_text = true
	_result_label.add_theme_font_size_override("font_size", RESULT_FONT)
	_result_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	row.add_child(_result_label)

	_run_all = TextureButton.new()
	# Before the texture, or the button takes the art's own 136x62 as its
	# minimum and the size below is silently clamped up to it.
	_run_all.ignore_texture_size = true
	_run_all.stretch_mode = TextureButton.STRETCH_SCALE
	_run_all.texture_normal = WIDE_ACTION_TEXTURE
	_run_all.custom_minimum_size = RUN_ALL_SIZE
	# Pinned, not filled: in a row as tall as its tallest child a stretched
	# TextureButton would scale the art vertically, and the caption inside it is
	# placed at the button's own size rather than anchored to it.
	_run_all.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_run_all.pressed.connect(_on_run_all_pressed)
	row.add_child(_run_all)

	_run_all_label = Label.new()
	_run_all_label.size = RUN_ALL_SIZE
	_run_all_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_run_all_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_run_all_label.add_theme_font_size_override("font_size", RUN_ALL_FONT)
	_run_all_label.add_theme_color_override("font_color", Color.WHITE)
	_run_all_label.add_theme_color_override("font_outline_color", Color(0.25, 0.10, 0.02, 1))
	_run_all_label.add_theme_constant_override("outline_size", 4)
	_run_all_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_run_all.add_child(_run_all_label)
	return row


# Says how many aircraft are waiting, so you know what the press will do
# before you make it - and goes dead when the answer is none.
func _refresh_run_all() -> void:
	if not is_instance_valid(_run_all):
		return
	# The lock SHOWS ITS LEVEL. A button that is simply absent, or greyed with
	# no reason, reads as broken rather than as something to play towards.
	if Progression.level < DEPART_ALL_LEVEL:
		_run_all.disabled = true
		_run_all.texture_normal = LOCKED_TEXTURE
		_run_all.modulate = Color(0.85, 0.85, 0.85, 1.0)
		_run_all_label.text = "Level %d" % DEPART_ALL_LEVEL
		return
	_run_all.texture_normal = WIDE_ACTION_TEXTURE
	var pending := Fleet.pending_count()
	_run_all.disabled = pending == 0
	_run_all.modulate = Color.WHITE if pending > 0 else Color(0.55, 0.55, 0.55, 1.0)
	# The count is on the panel's own "In service / Ready" line.
	_run_all_label.text = "Depart all"


# What the press actually did. Aircraft can refuse - no fuel, no free pad at
# the destination, out of range - so a silent button would leave you guessing
# which.
func _flash_result(result: Dictionary) -> void:
	var bits: Array = []
	if int(result["earned"]) > 0:
		bits.append("collected $%d" % int(result["earned"]))
	if int(result["departed"]) > 0:
		bits.append("%d departed" % int(result["departed"]))
	if int(result["fuel_spent"]) > 0:
		bits.append("%d fuel" % int(result["fuel_spent"]))
	# Name the causes rather than a bare count - "3 need 5 fuel" tells you to
	# go and buy fuel; "3 stuck" tells you nothing.
	var reasons: Dictionary = result.get("reasons", {})
	if reasons.is_empty():
		if int(result["blocked"]) > 0:
			bits.append("%d stuck" % int(result["blocked"]))
	else:
		for why in reasons:
			bits.append("%d %s" % [int(reasons[why]), why])
	_result_label.text = ", ".join(bits) if not bits.is_empty() else ""
	_result_timer = RESULT_HOLD


func _build_empty_label() -> void:
	_empty_label = Label.new()
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.custom_minimum_size = Vector2(520, 0)
	_empty_label.add_theme_font_size_override("font_size", 20)
	_empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_empty_label.visible = false
	_vbox.add_child(_empty_label)
	_vbox.move_child(_empty_label, _grid.get_index() + 1)


func _on_sort_pressed(sort: int) -> void:
	if sort == _sort:
		return
	_sort = sort
	_refresh()


# --- table ---------------------------------------------------------------

# In service = assigned to an apron. A parked aircraft counts: it's on the
# roster and its next action is to depart, which is exactly what this table is
# for.
func _routes() -> Array:
	var out: Array = []
	for a in Fleet.aircraft:
		if not a.is_idle():
			out.append(a)
	_prune_tap_order()
	out.sort_custom(_sorts_before)
	return out


# ONE comparator for all three modes, because the tap order has to come first in
# every one of them: a row you have just tapped goes to the back of the queue
# whatever the table happens to be sorted by.
func _sorts_before(x: FleetAircraft, y: FleetAircraft) -> bool:
	var rx := _tap_rank(x)
	var ry := _tap_rank(y)
	if rx != ry:
		# Rank 0 is "not tapped", and it sorts above everything that has been.
		# Among the tapped, oldest tap first, so they come back round in the
		# order you sent them away rather than in a heap at the bottom.
		if rx == 0 or ry == 0:
			return rx == 0
		return rx < ry
	match _sort:
		Sort.TYPE:
			var nx := _type_name(x)
			var ny := _type_name(y)
			if nx != ny:
				return nx < ny
		Sort.COMPLETED:
			# Ready-for-action first, then by how long until they are.
			var ax := _has_action(x)
			var ay := _has_action(y)
			if ax != ay:
				return ax
			if not is_equal_approx(x.flight_time_left, y.flight_time_left):
				return x.flight_time_left < y.flight_time_left
		_:
			if not is_equal_approx(x.flight_time_left, y.flight_time_left):
				return x.flight_time_left < y.flight_time_left
	# STABLE, on a key nothing else ties. sort_custom is not a stable sort, so
	# rows that tied were free to swap places on every rebuild - and since every
	# aircraft waiting on you sits at zero seconds left, under the default sort
	# that was most of the table, reshuffled on every single tap.
	return x.id < y.id


func _tap_rank(a: FleetAircraft) -> int:
	return int(_tap_order.get(a.id, 0))


# The stamp lasts until the aircraft has nothing left to do, not just until its
# bar lands. One press runs the whole lap, so that is usually the same moment -
# but an aircraft whose turnaround REFUSED (no fuel, no pad, out of range) is
# still sitting there ready, and it should stay at the back rather than jump
# under your finger again. Once it is in the air the stamp goes and the chosen
# sort has it back.
func _prune_tap_order() -> void:
	for id in _tap_order.keys():
		var a := Fleet.get_aircraft(int(id))
		if a == null or a.is_idle() or (not _has_action(a) and not _swoops.has(int(id))):
			_tap_order.erase(id)


func _has_action(a: FleetAircraft) -> bool:
	return ACTIONS.has(a.state)


func _type_name(a: FleetAircraft) -> String:
	for entry in ShopCatalog.ENTRIES:
		if entry["key"] == a.model_key:
			return entry["name"]
	return a.model_key


func _catalog_icon(a: FleetAircraft) -> Texture2D:
	for entry in ShopCatalog.ENTRIES:
		if entry["key"] == a.model_key:
			return load("res://assets/shop/%s" % entry["icon"])
	return null


func _time_text(a: FleetAircraft) -> String:
	if a.is_in_transit():
		return _countdown(a.flight_time_left)
	if not _has_action(a):
		return "-"
	# An aircraft that can't move says why. "Ready" beside a button that
	# refuses to do anything is worse than no label at all.
	var why := Fleet.block_reason(a)
	return why if why != "" else "Ready"


# A row in a table, so this stays compact - "11h 42m", not "11.7 hours". Long
# high-rating aircraft are away for hours (Fleet.CLOUD_BASE_MINUTES), and a bare
# seconds count would have read "61200s".
func _countdown(secs: float) -> String:
	var t := int(ceilf(secs))
	if t >= 86400:
		return "%dd %02dh" % [t / 86400, (t % 86400) / 3600]
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm %02ds" % [t / 60, t % 60]
	return "%ds" % t


func _destination_text(a: FleetAircraft) -> String:
	if a.state == FleetAircraft.State.PARKED:
		return "-"
	var info: Dictionary = Maps.entry(Fleet.destination_of(a)).get("visiting", {})
	return str(info.get("name", Fleet.DESTINATION_NAME))


func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()
	# The bubbles belonged to those rows. Cleared here rather than checked for
	# validity later, so a stale entry cannot outlive the row it came from.
	_swoop_nodes.clear()

	var routes := _routes()
	for a in routes:
		_grid.add_child(_build_row(a))

	if _count_label:
		var ready := 0
		for a in routes:
			if _has_action(a):
				ready += 1
		_count_label.text = "In service: %d   ·   Ready: %d" % [routes.size(), ready]
	_refresh_run_all()
	if _empty_label:
		_empty_label.visible = routes.is_empty()
		_empty_label.text = "No aircraft in service - assign one to an apron first."
	call_deferred("_fit_content")


func _build_row(a: FleetAircraft) -> Control:
	var row := Control.new()
	row.custom_minimum_size = ROW_SIZE
	row.set_meta("aircraft_id", a.id)

	row.add_child(_texture(ROW_BOARD, Vector2.ZERO, ROW_SIZE, TextureRect.STRETCH_SCALE))
	row.add_child(_texture(_catalog_icon(a),
		Vector2(COL_ICON, (ROW_SIZE.y - ICON_SIZE.y) * 0.5), ICON_SIZE,
		TextureRect.STRETCH_KEEP_ASPECT_CENTERED))

	row.add_child(_cell(_type_name(a), COL_TYPE, COL_DEST - COL_TYPE,
		HORIZONTAL_ALIGNMENT_LEFT))
	row.add_child(_cell(_destination_text(a), COL_DEST, COL_TIME - COL_DEST,
		HORIZONTAL_ALIGNMENT_CENTER))

	var time_label := _cell(_time_text(a), COL_TIME, COL_ACTION - COL_TIME,
		HORIZONTAL_ALIGNMENT_CENTER)
	row.add_child(time_label)
	row.set_meta("time_label", time_label)

	# ignore_texture_size BEFORE the texture, for the same reason the
	# TextureRects need expand_mode first: otherwise the button's minimum size
	# is its texture's, `size` clamps up to it, and the label - sized to what we
	# asked for - ends up off-centre inside a button that grew.
	if _swoops.has(a.id):
		# JUST THE BAR. The pads use ProgressBubble - a 96x58 oval with an icon
		# baked in - and dropping one into a 52px row of a list is a lump. The
		# bar is the part that carries the meaning; the oval was only ever the
		# frame it hangs in out on the board.
		var fuelling: bool = FUEL_STATES.has(a.state)
		var bar_x := COL_ACTION + (ACTION_SIZE.x - SWOOP_BAR_SIZE.x) * 0.5
		var bar_y := (ROW_SIZE.y - SWOOP_BAR_SIZE.y) * 0.5

		var track := ColorRect.new()
		track.color = SWOOP_TRACK
		track.position = Vector2(bar_x, bar_y)
		track.size = SWOOP_BAR_SIZE
		track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(track)

		var fill := ColorRect.new()
		fill.color = SWOOP_FUEL_COLOR if fuelling else SWOOP_EARN_COLOR
		fill.position = Vector2(bar_x, bar_y)
		fill.size = Vector2(SWOOP_BAR_SIZE.x * _swoop_fraction(a.id),
			SWOOP_BAR_SIZE.y)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(fill)
		_swoop_nodes[a.id] = fill
		return row

	var action := TextureButton.new()
	action.ignore_texture_size = true
	action.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	action.texture_normal = WIDE_ACTION_TEXTURE
	action.custom_minimum_size = ACTION_SIZE
	action.position = Vector2(COL_ACTION, (ROW_SIZE.y - ACTION_SIZE.y) * 0.5)
	action.size = ACTION_SIZE
	var has_action := _has_action(a)
	action.disabled = not has_action
	action.modulate = Color.WHITE if has_action else Color(0.55, 0.55, 0.55, 1.0)
	if has_action:
		action.pressed.connect(_on_action.bind(a.id))
	var action_label := Label.new()
	action_label.text = ACTIONS.get(a.state, "In flight")
	action_label.size = ACTION_SIZE
	# Clipped rather than allowed to spill past the art, so a caption that is
	# too long reads as truncated instead of as a broken button.
	action_label.clip_text = true
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.add_theme_font_size_override("font_size", ACTION_FONT)
	action_label.add_theme_color_override("font_color", Color.WHITE)
	action_label.add_theme_color_override("font_outline_color", Color(0.25, 0.10, 0.02, 1))
	action_label.add_theme_constant_override("outline_size", 3)
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action.add_child(action_label)
	row.add_child(action)
	return row


# expand_mode BEFORE the texture, and custom_minimum_size pinned: a TextureRect
# takes its minimum size from its texture, so assigning `size` while that
# minimum still applies silently clamps it up to the texture's dimensions -
# which is how a 52px icon came out 161px wide.
func _texture(tex: Texture2D, pos: Vector2, s: Vector2, stretch: int) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = stretch
	t.texture = tex
	t.custom_minimum_size = s
	t.position = pos
	t.size = s
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


func _cell(text: String, x: float, width: float, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(x, 0.0)
	l.size = Vector2(width, ROW_SIZE.y)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", ROW_FONT)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# The one button. Which call it makes depends only on where the aircraft is in
# its trip, so the player never has to know the difference.
#
# THE ROW LEAVES THE QUEUE ON THE TAP, not when its bar lands. Two seconds is
# long enough to keep tapping through, so a row that held its place would be the
# one under your finger for the next press - and with the fleet at sixty, a
# table that reordered itself only once each bar finished meant re-reading it
# after every press to find where the aircraft you had just dealt with had gone.
func _on_action(aircraft_id: int) -> void:
	if _swoops.has(aircraft_id):
		return
	_tap_seq += 1
	_tap_order[aircraft_id] = _tap_seq
	_swoops[aircraft_id] = 0.0
	_refresh()


# Advance every running swoop, and fire the ones that finish. Deliberately not
# blocking: like the pads, you can start one on every row and let them all run.
func _swoop_fraction(aircraft_id: int) -> float:
	return clampf(float(_swoops.get(aircraft_id, 0.0)) / SWOOP_SECONDS, 0.0, 1.0)


func _tick_swoops(delta: float) -> void:
	if _swoops.is_empty():
		return
	var done: Array = []
	for id in _swoops:
		_swoops[id] = float(_swoops[id]) + delta
		# THE BAR HAS TO BE PUSHED. show_status paints a fill and stops - it is
		# the static display the pads use for a countdown, not the animating
		# one - so without this the bubble appeared at zero, sat there for two
		# seconds and vanished. On screen that is a button disappearing and
		# nothing happening.
		var node = _swoop_nodes.get(id)
		if is_instance_valid(node):
			node.size.x = SWOOP_BAR_SIZE.x * _swoop_fraction(id)
		if float(_swoops[id]) >= SWOOP_SECONDS:
			done.append(id)
	for id in done:
		_swoops.erase(id)
		# ONE PRESS IS THE WHOLE TURNAROUND. advance() takes a single step, so
		# a landed aircraft needed Collect, then Return, then Refuel - three
		# presses and three two-second bars to send one aircraft out again,
		# times the length of the list. Depart All already runs each aircraft
		# as far as it will go in one press; this is that, for one row.
		var steps := 0
		while steps < Fleet.MAX_ADVANCE_STEPS and Fleet.advance(int(id)):
			steps += 1
	if not done.is_empty():
		_refresh()


func _on_run_all_pressed() -> void:
	# Belt and braces: the button is disabled below the gate, but a bulk
	# dispatch is the single most powerful press in the game and should not
	# depend on one Control's disabled flag being right.
	if Progression.level < DEPART_ALL_LEVEL:
		return
	var result := Fleet.advance_all()
	_flash_result(result)
