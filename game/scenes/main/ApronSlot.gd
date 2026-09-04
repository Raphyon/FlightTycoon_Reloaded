extends Area2D

signal clicked(apron: Apron)

const SIZE := Vector2(220, 110)

# WHAT IS SITTING ON THIS PAD, readable without opening anything. Three states,
# bottom-left of the pad so a row of them reads down the board:
#   free    nothing assigned
#   mine    an aircraft of yours
#   friend  one that came from somebody else
# Cut from source-assets/airport/airport@2x.png at 833,139 / 883,143 / 933,146.
const BADGE_FREE := preload("res://assets/aprons/pad_free@2x.png")
const BADGE_MINE := preload("res://assets/aprons/pad_mine@2x.png")
const BADGE_FRIEND := preload("res://assets/aprons/pad_friend@2x.png")
const BADGE_SCALE := 1.25
# ABOVE THE AIRCRAFT, BELOW THE CLOUD COVER. Slots live under Aprons and
# aircraft under WorldAircraft, a later sibling - so at the default z the badge
# was drawn and then painted over by whatever was parked on the pad. It needs to
# beat that.
#
# But CloudSlot is z_index 10, and 50 put the badge THROUGH the clouds - a pad
# you are not meant to be able to see, advertising whether it is free. 5 clears
# the aircraft at 0 and stays under the cover at 10.
const BADGE_Z_INDEX := 5
# THE PAD IS A DIAMOND, NOT A RECTANGLE. SIZE is its 220x110 bounding box, and
# the badge was placed at the bottom-left of THAT - which on an isometric tile
# is empty space well off the paint. Measured from the art: the top and bottom
# rows are a 2px sliver at the centre and only the middle row spans the full
# width, so the corners are at left(-110,0) top(0,-55) right(110,0)
# bottom(0,55).
#
# This is the badge's CENTRE, on the lower-left edge that runs from the left
# corner to the bottom corner, pulled inside it far enough to sit on paint:
# |x|/110 + |y|/55 = 0.93, just within the diamond. Nudge this one Vector2 to
# move it along that edge.
# PLACED BY EYE with the F1 badge tool, not solved for. It sits at the pad's
# LEFT vertex - which is what "the bottom-left corner" means on a diamond seen
# in projection, and is why three attempts at deriving it landed halfway along
# the lower-left edge instead.
#
# It deliberately OVERHANGS: the badge's outer corner reaches |x|/110 + |y|/55 =
# 1.15, so part of it is off the paint. That was the choice made looking at it,
# and the "must sit entirely on the diamond" rule the earlier attempts obeyed
# was invented rather than asked for.
#
# NOT a const: BadgePlacer moves this at runtime so the spot can be chosen on a
# real pad, and every pad reads the same value.
#
# LOADED FROM data/badge_offset.json IF IT IS THERE, exactly like the apron,
# cloud and path layouts - it is placed with an in-game tool, so it is CONTENT,
# and content that only survives in a console log is content that gets lost. The
# value below is the fallback for a checkout that has no file yet.
const BADGE_PATH := "res://data/badge_offset.json"

static var badge_offset := Vector2(-94.0, -2.0)
static var _badge_loaded := false


static func load_badge_offset() -> Vector2:
	if _badge_loaded:
		return badge_offset
	_badge_loaded = true
	if not FileAccess.file_exists(BADGE_PATH):
		return badge_offset
	var f := FileAccess.open(BADGE_PATH, FileAccess.READ)
	if not f:
		return badge_offset
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary and parsed.has("x") and parsed.has("y"):
		badge_offset = Vector2(float(parsed["x"]), float(parsed["y"]))
	return badge_offset


static func save_badge_offset() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(BADGE_PATH, FileAccess.WRITE)
	if not f:
		push_warning("ApronSlot: could not write %s" % BADGE_PATH)
		return
	f.store_string(JSON.stringify({"x": badge_offset.x, "y": badge_offset.y}, "\t"))
	f.close()
const COLOR_FREE := Color(0.2, 0.9, 0.4, 0.25)
const COLOR_OCCUPIED := Color(0.9, 0.5, 0.2, 0.35)
const COLOR_HOVER := Color(1, 1, 1, 0.4)
const COLOR_LOCKED_FALLBACK := Color(0.4, 0.4, 0.4, 0.35)
# An unbuilt pad, by terrain. The paved zones keep the apron art they always
# had; the unpaved ones get machinery standing on the ground.
#
# The unpaved zones had NO art at all before this and fell back to a flat
# coloured diamond - COLOR_LOCKED_FALLBACK, which is still what a LOCKED zone
# draws, but an unlocked-and-unbuilt pad in the Forest was a grey lozenge with
# a cone floating over it.
const UNDER_CONSTRUCTION_TEXTURE := preload("res://assets/aprons/apron9@2x.png")
const UNDER_CONSTRUCTION_WILD_TEXTURE := preload("res://assets/buildings/construction_site_forest_2x.png")
# THE WILD ART STANDS ON ITS GROUND; THE PAVED ART IS THE GROUND. apron9 is a
# taped-off diamond whose dirt fills the tile, so centring it in the slot is
# right. The wild texture is a scene - a dirt patch low in the frame with an
# excavator and a roller standing on top of it - and its ground plane sits at
# about 0.74 of the sprite's height rather than the middle. Centred, that put
# the dirt 26px below the diamond's centre and the machinery looked sunk into
# the plot in front.
#
# 120x81 into a 220x110 slot is height-bound, so it draws 163x110 and the lift
# is (0.74 - 0.5) x 110. Applied only to the wild texture; the paved one is
# already where it belongs.
const UNDER_CONSTRUCTION_WILD_LIFT := 26.0
# WHERE THE TAPED DIAMOND ACTUALLY IS INSIDE ITS BITMAP, measured off the file
# rather than assumed. apron9 is 207x113, but the ground diamond is not what
# fills it: the silhouette's top vertex is a tape POST, so the diamond's waist
# - its widest row, 206px across - sits at y=60 while the bitmap's own centre
# is 56.5, and the lower vertex is at y=111. Ground diamond: centre (103.5,
# 60), half-extents (103, 51), aspect 2.02 against the tile's 2.00.
#
# Fitting the BITMAP to the tile therefore never fits the DIAMOND to it. At
# 220x110 the ground's top vertex landed 8.8px inside the tile - the asphalt
# edge showing above the tape - while its base ran past the bottom. Scaling
# the diamond's half-extents onto the tile's instead gives 1.068 x 1.078, so
# the bitmap draws at 221x122 offset to put the waist on the tile's centre.
const PAVED_ART_SIZE := Vector2(221.1, 121.9)
const PAVED_ART_POSITION := Vector2(-110.5, -64.7)
# One-piece callouts: the icon is part of the art, so there is nothing to
# centre. These were a shared bubble with an icon laid on top, positioned by
# "(bubble width - icon width) * 0.5 - 3.0, 6.0" - a fudge per axis that never
# quite landed, and looked it.
const CALLOUT_CONE_TEXTURE := preload("res://assets/bubbles/cone_bubble@2x.png")
const CALLOUT_PLANE_TEXTURE := preload("res://assets/bubbles/aircraft_bubble@2x.png")
const CALLOUT_DOLLAR_TEXTURE := preload("res://assets/bubbles/cash_bubble@2x.png")
const CALLOUT_DRUM_TEXTURE := preload("res://assets/bubbles/fuel_bubble@2x.png")
# A whole composed bubble rather than an icon in the round one - the word, the
# bar and the plane are all baked in (tools/arrived_label.py). Shown on a home
# apron whose aircraft is waiting at the robot airport; clicking it travels
# there.
# Two arrived bubbles, and which one shows follows the same BLUE/GREEN rule as
# the flight tag: blue at your own airport, green the moment a friend is
# involved. The green one reads as "your aircraft is home" while you are away
# visiting, which is the only time you can be looking at a pad that is not
# yours. Both have the plane baked in - they are composed sprites, not a bubble
# plus an icon.
const CALLOUT_ARRIVED_TEXTURE := preload("res://assets/bubbles/arrived_bubble_new@2x.png")
const CALLOUT_ARRIVED_HOME_TEXTURE := preload("res://assets/bubbles/arrived_home_new@2x.png")
# The swoop family - one 96x58 oval per kind of work, icon baked in, the rest of
# the oval left empty for the line of text and the bar (see ProgressBubble).
const SWOOP_EARNING_TEXTURE := preload("res://assets/bubbles/earning_bubble@2x.png")
const SWOOP_FUELING_TEXTURE := preload("res://assets/bubbles/fueling_bubble@2x.png")
# The flight tag - same oval, plane icon, and it is the COLOUR that says whose
# aircraft you are looking at.
#
#   BLUE  your own aircraft, at your own airport
#   GREEN anything friend-shaped: your aircraft while you are visiting a
#         friend, and - once friends can send aircraft to you - theirs parked
#         on your pads. Nothing does that yet; there is no notion of another
#         player's aircraft in Fleet, so only the visiting half is live.
# What the swoop says while it works. Verbs, not figures - see ProgressBubble.
const SWOOP_CLAIM_TEXT := "Claiming"
const SWOOP_FUEL_TEXT := "Refueling"

const TAG_MINE_TEXTURE := preload("res://assets/bubbles/arrived_away_bubble@2x.png")
const TAG_FRIEND_TEXTURE := preload("res://assets/bubbles/arrived_home_bubble@2x.png")
# Native art size - drawn 1:1, so it stays crisp.
const CALLOUT_BUBBLE_SIZE := Vector2(42, 49)
const CALLOUT_ARRIVED_SIZE := Vector2(42, 50)
# The arrived bubble used to be 109 wide with its plane hanging off the left
# edge, which put the tail off-centre at ~34% and needed its own figure. The
# replacement art is the same 42-wide callout as the cone, symmetric, with its
# tail tip measured at x 20.6 - so this is simply half the width again.
const CALLOUT_ARRIVED_TAIL_X := 21.0
# Where the bubble's tail tip lands, relative to the apron's center (0,0) -
# negative is above center. A little above center, not up at the top vertex.
const CALLOUT_TAIL_Y := -20.0
# Absolute (not parent-relative) draw layer for the status bubble, so it
# clears the aircraft and road traffic that live in later scene-tree nodes.
const CALLOUT_Z_INDEX := 100

# The construction-tape diamond is sized/colored for the paved zones - on
# natural terrain (foliage, sand, snow) it visually clashes with what's
# already there, so those zones fall back to a plain tint instead.
const PAVED_ZONES: Array[String] = ["Zone1", "Zone2", "DarkZone"]

var apron: Apron
var _hovering := false
var _under_construction: TextureRect
var _skin_overlay: TextureRect
var _callout: Control
var _callout_bubble: TextureRect
var _callout_icon: TextureRect
var _pending_action: Callable = Callable()
# What the tap should SHOW while it works. Armed alongside _pending_action so
# the two cannot disagree about which action is pending.
var _swoop_texture: Texture2D = null
var _swoop_text := ""
var _swoop_is_fuel := false
var _swoop: ProgressBubble
# The flight tag: a countdown while the aircraft is in the air, "Arrived" once
# it is down. Separate from _swoop because the two can want the space at
# different times and neither should clear the other.
var _tag: ProgressBubble
var _tag_action: Callable = Callable()
var _badge: TextureRect
var _tag_aircraft: FleetAircraft = null
# The skin path the overlay is already holding a texture for. _draw ran load()
# on every redraw, and a redraw is not a rare thing here - every pad repaints on
# every build, skin change, zone unlock and hover. ResourceLoader hands back a
# cached resource, but only after normalising the path and taking its lock, and
# a pad's skin only changes on ApronSkins.skin_changed, which redraws it anyway.
var _skin_path := ""


func setup(p_apron: Apron) -> void:
	apron = p_apron
	position = apron.screen_pos
	ApronProgress.built_changed.connect(queue_redraw)
	ApronSkins.skin_changed.connect(queue_redraw)
	DebugState.flags_changed.connect(queue_redraw)
	# Buying a zone in the expansion shop has to bring its aprons' build
	# prompts in straight away, without waiting on some other repaint.
	ZoneProgress.unlocked_changed.connect(queue_redraw)
	# The in-transit countdown shows only while THIS pad's menu is open, and
	# opening a menu changes no game state - so without this nothing would tell
	# the slot to look again and the bubble never appeared.
	var panel := get_node_or_null("../../UI/ApronInfoPanel")
	if panel and panel.has_signal("shown_apron_changed"):
		panel.shown_apron_changed.connect(func(_id: int) -> void: queue_redraw())
	queue_redraw()


func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(func() -> void:
		_hovering = true
		queue_redraw()
	)
	mouse_exited.connect(func() -> void:
		_hovering = false
		queue_redraw()
	)

	var shape := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	poly.points = _diamond_points()
	shape.shape = poly
	add_child(shape)

	_under_construction = TextureRect.new()
	_under_construction.texture = UNDER_CONSTRUCTION_TEXTURE
	var hw := SIZE.x * 0.5
	var hh := SIZE.y * 0.5
	_under_construction.position = Vector2(-hw, -hh)
	_under_construction.size = SIZE
	_under_construction.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_under_construction.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_under_construction.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_under_construction)

	_skin_overlay = TextureRect.new()
	_skin_overlay.position = Vector2(-hw, -hh)
	_skin_overlay.size = SIZE
	_skin_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_skin_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_skin_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin_overlay.visible = false
	add_child(_skin_overlay)

	_badge = TextureRect.new()
	_badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.z_index = BADGE_Z_INDEX
	# Absolute, like the callouts - a badge that inherited the slot's z would
	# sort differently depending on which pad it belongs to.
	_badge.z_as_relative = false
	var bs := BADGE_FREE.get_size() * BADGE_SCALE
	_badge.size = bs
	# Bottom-left corner of the pad, inset so it sits ON the apron rather than
	# on its edge.
	_badge.position = load_badge_offset() - bs * 0.5
	_badge.visible = false
	add_child(_badge)

	# Status callout - a bubble with an icon in it (cone = needs building,
	# plane = free and ready to assign, dollar = reward ready to claim,
	# drum = needs fuel), tail pointing down at a spot a little above the
	# apron's center.
	_callout = Control.new()
	_callout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.position = Vector2(-CALLOUT_BUBBLE_SIZE.x * 0.5, CALLOUT_TAIL_Y - CALLOUT_BUBBLE_SIZE.y)
	_callout.size = CALLOUT_BUBBLE_SIZE
	# Aprons sit before WorldAircraft and RoadTraffic in the scene tree, so
	# a parked plane (or a passing lorry) would paint straight over the
	# bubble. Lifting it to an absolute z keeps it on top without
	# reordering the nodes - reordering would put the apron tiles above the
	# aircraft too, which is worse. Node2D content only; the UI CanvasLayer
	# is still above all of this.
	_callout.z_index = CALLOUT_Z_INDEX
	_callout.z_as_relative = false
	add_child(_callout)

	_callout_bubble = TextureRect.new()
	_callout_bubble.texture = CALLOUT_CONE_TEXTURE
	_callout_bubble.size = CALLOUT_BUBBLE_SIZE
	_callout_bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_callout_bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_callout_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.add_child(_callout_bubble)

	_callout_icon = TextureRect.new()
	_callout_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_callout_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_callout_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_callout.add_child(_callout_icon)

	# Its own node rather than a mode of the callout: the swoop has to keep
	# drawing after the callout it replaced has gone (the claim clears the
	# state the callout was reporting), and two nodes cannot fight over that.
	_swoop = ProgressBubble.new()
	_swoop.z_index = CALLOUT_Z_INDEX
	_swoop.z_as_relative = false
	_swoop.visible = false
	add_child(_swoop)
	ProgressBubble.place_by_tail(_swoop, Vector2(0, CALLOUT_TAIL_Y))
	_swoop.completed.connect(func() -> void:
		_swoop.visible = false
		queue_redraw()
	)

	_tag = ProgressBubble.new()
	_tag.z_index = CALLOUT_Z_INDEX
	_tag.z_as_relative = false
	_tag.visible = false
	add_child(_tag)
	ProgressBubble.place_by_tail(_tag, Vector2(0, CALLOUT_TAIL_Y))

	_set_callout_icon(CALLOUT_CONE_TEXTURE)


# Arms the callout AND what its tap will show while it works. Cash actions get
# the earning bubble and the figure they will pay; fuel actions get the fuelling
# bubble and what the tank costs. Anything armed without a swoop (the cone, the
# free-pad plane) still fires instantly - there is nothing to watch.
func _arm(icon: Texture2D, action: Callable, swoop: Texture2D = null,
		text := "", is_fuel := false) -> void:
	_swoop_texture = swoop
	_swoop_text = text
	_swoop_is_fuel = is_fuel
	_set_callout_icon(icon, action)


func _set_callout_icon(texture: Texture2D, action: Callable = Callable()) -> void:
	_callout_bubble.texture = texture
	_callout_bubble.size = CALLOUT_BUBBLE_SIZE
	_callout.size = CALLOUT_BUBBLE_SIZE
	_callout.position = Vector2(-CALLOUT_BUBBLE_SIZE.x * 0.5, CALLOUT_TAIL_Y - CALLOUT_BUBBLE_SIZE.y)
	_callout_icon.visible = false
	_pending_action = action


# The "Arrived" callout: one composed sprite, so there's no separate icon, and
# it's placed by its tail rather than its centre.
func _set_callout_arrived(action: Callable) -> void:
	# No swoop: this is "take me there", not a job being done.
	_swoop_texture = null
	_callout_bubble.texture = CALLOUT_ARRIVED_HOME_TEXTURE if Maps.is_robot_map() \
		else CALLOUT_ARRIVED_TEXTURE
	_callout_bubble.size = CALLOUT_ARRIVED_SIZE
	_callout.size = CALLOUT_ARRIVED_SIZE
	_callout.position = Vector2(-CALLOUT_ARRIVED_TAIL_X, CALLOUT_TAIL_Y - CALLOUT_ARRIVED_SIZE.y)
	_callout_icon.visible = false
	_pending_action = action


# Claims bubble clicks in _input (fires before physics picking) rather than
# a second Area2D - a second Area2D's own picking doesn't reliably preempt
# this node's own diamond Area2D for the same click (same class of bug as
# CloudLayer vs ApronSlot earlier - both would fire, and the diamond's own
# click would pop the info panel over top of the bubble action).
func _input(event: InputEvent) -> void:
	var tag_live: bool = is_instance_valid(_tag) and _tag.visible and _tag_action.is_valid()
	if not tag_live and (not _pending_action.is_valid() or not _callout.visible):
		return
	# NOT WHILE A PANEL IS UNDER THE POINTER. _input runs BEFORE the GUI gets a
	# look, so a click on the aircraft shop reached the bubble underneath it too
	# - and if that bubble said "Arrived", a mis-click inside a menu travelled
	# you to the robot airport. Physics picking is filtered for us; this handler
	# is not, so it has to ask.
	if get_viewport().gui_get_hovered_control() != null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = to_local(get_global_mouse_position())
		var bubble_rect := Rect2(_callout.position, _callout.size)
		if _tag.visible and _tag_action.is_valid() \
				and Rect2(_tag.position, _tag.size).has_point(local_pos):
			get_viewport().set_input_as_handled()
			_tag_action.call()
			return
		if bubble_rect.has_point(local_pos):
			get_viewport().set_input_as_handled()
			_start_action()


func _diamond_points() -> PackedVector2Array:
	var hw := SIZE.x * 0.5
	var hh := SIZE.y * 0.5
	return PackedVector2Array([Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)])


func _draw() -> void:
	_refresh_badge()
	if not apron.built:
		var on_paved_zone := apron.area_name in PAVED_ZONES
		_under_construction.texture = (UNDER_CONSTRUCTION_TEXTURE if on_paved_zone
			else UNDER_CONSTRUCTION_WILD_TEXTURE)
		# Rect and stretch both follow the texture, because the two agree on
		# nothing except which node draws them.
		#
		# THE PAVED ART IS A COVERING FOR THE TILE, so it is placed by its own
		# diamond rather than by its bitmap - see PAVED_ART_SIZE. Stretched
		# outright, since a diamond drawn for this footprint arriving at this
		# footprint is not a distortion.
		#
		# THE WILD ART STANDS ON THE TILE, so it keeps its aspect and its
		# ground-line lift. Stretching an excavator to a 2:1 footprint would
		# look like exactly what it is.
		if on_paved_zone:
			_under_construction.stretch_mode = TextureRect.STRETCH_SCALE
			_under_construction.size = PAVED_ART_SIZE
			_under_construction.position = PAVED_ART_POSITION
		else:
			_under_construction.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_under_construction.size = SIZE
			_under_construction.position = Vector2(-SIZE.x * 0.5,
				-SIZE.y * 0.5 - UNDER_CONSTRUCTION_WILD_LIFT)
		_under_construction.visible = true
		# Nothing in a locked zone can be built until the zone itself is
		# bought in the expansion shop, so it gets no "build me" prompt and
		# no price. The bubble in particular has to go: it sits on an
		# absolute z-layer (see CALLOUT_Z_INDEX) and would otherwise float
		# on top of the cloud that's meant to be covering the whole zone.
		# A locked zone shows nothing at all - it is under cloud cover, and a
		# construction site peeking through would say "build here" about a zone
		# you cannot build in.
		if not ZoneProgress.is_unlocked(apron.area_name):
			_callout.visible = false
			_under_construction.visible = false
			if not on_paved_zone:
				draw_colored_polygon(_diamond_points(), COLOR_LOCKED_FALLBACK)
			return
		_set_callout_icon(CALLOUT_CONE_TEXTURE)
		_callout.visible = true
		if DebugState.show_apron_costs:
			draw_string(
				ThemeDB.fallback_font, Vector2(-40, 5),
				"$%d" % ApronProgress.cost_for_area(apron.area_name),
				HORIZONTAL_ALIGNMENT_CENTER, 80, 14, Color.WHITE
			)
		return
	_under_construction.visible = false

	var skin_entry := ApronSkins.get_skin_entry(apron.id)
	if skin_entry.size() > 0:
		var skin_path := str(skin_entry["texture"])
		if skin_path != _skin_path:
			_skin_overlay.texture = load(skin_path)
			_skin_path = skin_path
		_skin_overlay.visible = true
	else:
		_skin_overlay.visible = false

	# A pad at the robot airport, holding an aircraft you've flown out. Checked
	# first: robot pads have their own ids, so nothing else can be here.
	# A swoop in flight owns the space above this pad until it finishes.
	if is_instance_valid(_swoop) and _swoop.is_running():
		_callout.visible = false
		_hide_tag()
		return
	# Re-established below by whichever branch wants it.
	_hide_tag()
	var visitor := Fleet.get_aircraft_at_robot_apron(apron.id)
	if visitor:
		if visitor.state == FleetAircraft.State.AWAITING_DEST_CLAIM:
			_arm(CALLOUT_DOLLAR_TEXTURE, Fleet.claim_destination_reward.bind(visitor.id),
				SWOOP_EARNING_TEXTURE, SWOOP_CLAIM_TEXT)
		else:
			_arm(CALLOUT_DRUM_TEXTURE, Fleet.refuel_at_destination.bind(visitor.id),
				SWOOP_FUELING_TEXTURE, SWOOP_FUEL_TEXT, true)
		_callout.visible = true
	elif Maps.is_robot_map() and _holder() != null:
		# THE PAD IS HELD BUT THE AIRCRAFT IS NOT ON IT - it is in the air, or
		# already back at your airport. Exactly the state a home pad is in
		# while its aircraft is away, and it gets exactly the same treatment:
		# the flight tag, counting down while it flies and reading "Arrived"
		# with the way back on it once it is down. _tag_texture picks the green
		# one here on its own.
		var held := _holder()
		_callout.visible = false
		if Fleet.is_flying(held):
			_show_tag(held, Fleet.time_left_text(held.flight_time_left),
				Fleet.flight_progress(held), Callable())
		else:
			_show_tag(held, "Arrived", 1.0, Maps.travel_to.bind(Maps.DEFAULT_MAP))
	elif not apron.occupied:
		# The free-pad plane bubble means "assign one here", which you can't do
		# at the robot airport - its empty pads are just unused landing slots,
		# so offering the prompt there would invite a blocked action.
		if Maps.is_robot_map():
			_callout.visible = false
		else:
			_set_callout_icon(CALLOUT_PLANE_TEXTURE)
			_callout.visible = true
	else:
		var a := Fleet.get_aircraft_at_apron(apron.id)
		var state: int = a.state if a else -1
		match state:
			FleetAircraft.State.PARKED:
				_arm(CALLOUT_DRUM_TEXTURE, Fleet.fuel_and_depart.bind(a.id),
					SWOOP_FUELING_TEXTURE, SWOOP_FUEL_TEXT, true)
				_callout.visible = true
			FleetAircraft.State.FLYING_OUT, FleetAircraft.State.FLYING_BACK:
				# IN THE AIR. The countdown is a detail, not a prompt - there is
				# nothing to tap - so it only shows while this pad's own menu is
				# open, which is what the reference game does. Arrived is the
				# opposite: it IS a prompt, so it shows unasked (below).
				_callout.visible = false
				if _panel_open_here():
					_show_tag(a, Fleet.time_left_text(a.flight_time_left),
						Fleet.flight_progress(a), Callable())
				else:
					_hide_tag()
			FleetAircraft.State.AWAITING_DEST_CLAIM, FleetAircraft.State.AWAITING_DEST_REFUEL:
				# The aircraft isn't here - it's sitting at the destination it
				# flew to. This is its home pad, so it shows the way there
				# instead of the reward/fuel bubble it would show if the plane
				# were present. Which destination depends on the route, now
				# that there are five of them.
				_callout.visible = false
				_show_tag(a, "Arrived", 1.0, Maps.travel_to.bind(Fleet.destination_of(a)))
			FleetAircraft.State.AWAITING_HOME_CLAIM:
				_arm(CALLOUT_DOLLAR_TEXTURE, Fleet.claim_home_reward.bind(a.id),
					SWOOP_EARNING_TEXTURE, SWOOP_CLAIM_TEXT)
				_callout.visible = true
			FleetAircraft.State.AWAITING_HOME_REFUEL:
				_arm(CALLOUT_DRUM_TEXTURE, Fleet.refuel_and_depart.bind(a.id),
					SWOOP_FUELING_TEXTURE, SWOOP_FUEL_TEXT, true)
				_callout.visible = true
			_:
				# In the air - nothing to click at either airport.
				_callout.visible = false

	# The hover highlight stays on always - it's the affordance telling you the
	# tile is clickable. The flat green/orange free-vs-occupied tints and the
	# id number were only ever there to lay the airport out, so they sit
	# behind debug flags (F1) instead of covering the apron art.
	if _hovering:
		draw_colored_polygon(_diamond_points(), COLOR_HOVER)
	elif DebugState.show_apron_tints:
		draw_colored_polygon(_diamond_points(), COLOR_OCCUPIED if apron.occupied else COLOR_FREE)

	if DebugState.show_apron_ids:
		draw_string(
			ThemeDB.fallback_font, Vector2(-8, 5), str(apron.id),
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16, Color.WHITE
		)


# BLUE for your own aircraft at your own airport, GREEN the moment a friend is
# involved. Today that means "am I visiting", since nobody else's aircraft can
# be here yet; when they can, this is the one place that decides.
# What this destination pad is reserved for, whatever state it is in. Only ever
# consulted on a friend's map - at home the pad's aircraft is assigned_apron_id.
# Which badge this pad should be wearing, or null for none.
#
# FRIEND IS WIRED BUT UNREACHABLE TODAY. Nothing in the game models an aircraft
# belonging to somebody else sitting on a pad - a friend's airport is a robot
# map with your own fleet on it - so the green one has no case that produces it
# yet. It is here rather than left out because the state is part of the design
# and the art exists; the day foreign aircraft are modelled this reads them.
func _badge_texture() -> Texture2D:
	if not apron.built or not ZoneProgress.is_unlocked(apron.area_name):
		return null
	var a: FleetAircraft = (_holder() if Maps.is_robot_map()
		else Fleet.get_aircraft_at_apron(apron.id))
	if a == null:
		return BADGE_FREE
	return BADGE_MINE


func _refresh_badge() -> void:
	if not is_instance_valid(_badge):
		return
	var tex := _badge_texture()
	_badge.texture = tex
	_badge.visible = tex != null
	_badge.position = badge_offset - _badge.size * 0.5


func _holder() -> FleetAircraft:
	return Fleet.get_aircraft_holding_robot_apron(apron.id)


func _tag_texture() -> Texture2D:
	return TAG_FRIEND_TEXTURE if Maps.is_robot_map() else TAG_MINE_TEXTURE


# Show the flight tag. `action` empty means it is a readout, not a button.
func _show_tag(a: FleetAircraft, text: String, fill: float, action: Callable) -> void:
	_tag_aircraft = a
	_tag_action = action
	_tag.show_status(_tag_texture(), text, fill)
	# Only a live countdown needs the frame loop; an arrived tag never changes.
	set_process(_tag_aircraft != null and Fleet.is_flying(_tag_aircraft))


func _hide_tag() -> void:
	if not is_instance_valid(_tag):
		return
	_tag.visible = false
	_tag_action = Callable()
	_tag_aircraft = null
	set_process(false)


# The countdown, ticked in place rather than by redrawing the whole slot - a
# redraw re-evaluates every apron state and rebuilds the callout, once a frame,
# on every pad with an aircraft in the air.
func _process(_delta: float) -> void:
	if _tag_aircraft == null or not _tag.visible:
		set_process(false)
		return
	if not Fleet.is_flying(_tag_aircraft) or not _panel_open_here():
		# Landed, or the menu was closed under it - let the normal path decide.
		queue_redraw()
		return
	_tag.show_status(_tag_texture(),
		Fleet.time_left_text(_tag_aircraft.flight_time_left),
		Fleet.flight_progress(_tag_aircraft))


# Is this pad's own menu the one on screen?
func _panel_open_here() -> bool:
	var panel := get_node_or_null("../../UI/ApronInfoPanel")
	if panel == null or not panel.has_method("showing_apron_id"):
		return false
	return panel.showing_apron_id() == apron.id


# Fire the armed action - through the swoop where there is one to watch.
#
# The action runs when the BAR FILLS, not when the tap lands, so the two seconds
# ARE the transaction rather than a flourish over an outcome already decided.
# The callout hides at once, so one pad cannot be tapped twice into two swoops
# for one reward.
#
# Nothing blocks. Every other pad stays live and can start its own swoop on top
# of this one - see the note in ProgressBubble about why that matters.
func _start_action() -> void:
	var action := _pending_action
	if not action.is_valid():
		return
	if _swoop_texture == null:
		action.call()
		return
	_pending_action = Callable()
	_callout.visible = false
	_swoop.run(_swoop_texture, _swoop_text, action, _swoop_is_fuel)


# A press is not a click yet - it might be the start of a camera drag.
#
# The slots are 220x110 but sit 128px apart, so they overlap and tile the whole
# airport with no gaps between them. Consuming the press outright therefore ate
# every drag that started anywhere near the pads, and the more you built the
# less of the world was left to grab: at 35 pads there was almost nowhere to
# pan from. So the press is left alone, and the panel opens on RELEASE only if
# the pointer stayed put - a tap opens the apron, a drag moves the camera.
const DRAG_SLOP := 6.0

var _press_position := Vector2.ZERO
var _pressed := false


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = true
			_press_position = event.position
			# Deliberately NOT handled here - the camera needs to see it to
			# start a drag.
		elif _pressed:
			_pressed = false
			if event.position.distance_to(_press_position) <= DRAG_SLOP:
				# A LOCKED ZONE SWALLOWS THE CLICK AND OPENS NOTHING. The pad
				# under cloud cover still has a collision shape, so it was
				# emitting clicked like any other - an info panel for a pad the
				# player cannot see, reached by clicking a cloud. Handled
				# rather than ignored, so the press does not fall through to
				# whatever sits behind the cover either.
				get_viewport().set_input_as_handled()
				if not ZoneProgress.is_unlocked(apron.area_name):
					return
				clicked.emit(apron)
