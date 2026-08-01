extends Area2D

signal clicked(apron: Apron)

const SIZE := Vector2(220, 110)
const COLOR_FREE := Color(0.2, 0.9, 0.4, 0.25)
const COLOR_OCCUPIED := Color(0.9, 0.5, 0.2, 0.35)
const COLOR_HOVER := Color(1, 1, 1, 0.4)
const COLOR_LOCKED_FALLBACK := Color(0.4, 0.4, 0.4, 0.35)
const UNDER_CONSTRUCTION_TEXTURE := preload("res://assets/aprons/apron9@2x.png")
const CALLOUT_BUBBLE_TEXTURE := preload("res://assets/bubbles/callout_bubble@2x.png")
const CALLOUT_CONE_TEXTURE := preload("res://assets/bubbles/cone_icon@2x.png")
const CALLOUT_PLANE_TEXTURE := preload("res://assets/bubbles/black_plane_icon@2x.png")
const CALLOUT_DOLLAR_TEXTURE := preload("res://assets/bubbles/dollar_icon@2x.png")
const CALLOUT_DRUM_TEXTURE := preload("res://assets/bubbles/drum_icon@2x.png")
# A whole composed bubble rather than an icon in the round one - the word, the
# bar and the plane are all baked in (tools/arrived_label.py). Shown on a home
# apron whose aircraft is waiting at the robot airport; clicking it travels
# there.
const CALLOUT_ARRIVED_TEXTURE := preload("res://assets/bubbles/arrived_bubble@2x.png")
const CALLOUT_BUBBLE_SIZE := Vector2(42, 50)
const CALLOUT_CONE_SIZE := Vector2(25, 24)
const CALLOUT_PLANE_SIZE := Vector2(29, 24)
const CALLOUT_DOLLAR_SIZE := Vector2(22, 27)
const CALLOUT_DRUM_SIZE := Vector2(20, 27)
const CALLOUT_ARRIVED_SIZE := Vector2(109, 58)
# Where the arrived bubble's tail sits horizontally. Not half its width: the
# plane icon overhangs the bubble's left edge, so the tail is off-centre at
# ~34%, and centring the sprite would leave it pointing wide of the apron.
const CALLOUT_ARRIVED_TAIL_X := 37.0
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


func setup(p_apron: Apron) -> void:
	apron = p_apron
	position = apron.screen_pos
	ApronProgress.built_changed.connect(queue_redraw)
	ApronSkins.skin_changed.connect(queue_redraw)
	DebugState.flags_changed.connect(queue_redraw)
	# Buying a zone in the expansion shop has to bring its aprons' build
	# prompts in straight away, without waiting on some other repaint.
	ZoneProgress.unlocked_changed.connect(queue_redraw)
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
	_callout_bubble.texture = CALLOUT_BUBBLE_TEXTURE
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

	_set_callout_icon(CALLOUT_CONE_TEXTURE, CALLOUT_CONE_SIZE)


func _set_callout_icon(texture: Texture2D, size: Vector2, action: Callable = Callable()) -> void:
	_callout_bubble.texture = CALLOUT_BUBBLE_TEXTURE
	_callout_bubble.size = CALLOUT_BUBBLE_SIZE
	_callout.size = CALLOUT_BUBBLE_SIZE
	_callout.position = Vector2(-CALLOUT_BUBBLE_SIZE.x * 0.5, CALLOUT_TAIL_Y - CALLOUT_BUBBLE_SIZE.y)
	_callout_icon.visible = true
	_callout_icon.texture = texture
	_callout_icon.size = size
	_callout_icon.position = Vector2((CALLOUT_BUBBLE_SIZE.x - size.x) * 0.5 - 3.0, 6.0)
	_pending_action = action


# The "Arrived" callout: one composed sprite, so there's no separate icon, and
# it's placed by its tail rather than its centre.
func _set_callout_arrived(action: Callable) -> void:
	_callout_bubble.texture = CALLOUT_ARRIVED_TEXTURE
	_callout_bubble.size = CALLOUT_ARRIVED_SIZE
	_callout.size = CALLOUT_ARRIVED_SIZE
	_callout.position = Vector2(-CALLOUT_ARRIVED_TAIL_X, CALLOUT_TAIL_Y - CALLOUT_ARRIVED_SIZE.y)
	_callout_icon.visible = false
	_pending_action = action


# Claims bubble clicks in _input (fires before physics picking) rather than
# a second Area2D - a second Area2D's own picking doesn't reliably preempt
# this node's own diamond Area2D for the same click (same class of bug as
# CloudEditor vs ApronSlot earlier - both would fire, and the diamond's own
# click would pop the info panel over top of the bubble action).
func _input(event: InputEvent) -> void:
	if not _pending_action.is_valid() or not _callout.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var local_pos: Vector2 = to_local(get_global_mouse_position())
		var bubble_rect := Rect2(_callout.position, CALLOUT_BUBBLE_SIZE)
		if bubble_rect.has_point(local_pos):
			get_viewport().set_input_as_handled()
			_pending_action.call()


func _diamond_points() -> PackedVector2Array:
	var hw := SIZE.x * 0.5
	var hh := SIZE.y * 0.5
	return PackedVector2Array([Vector2(0, -hh), Vector2(hw, 0), Vector2(0, hh), Vector2(-hw, 0)])


func _draw() -> void:
	if not apron.built:
		var on_paved_zone := apron.area_name in PAVED_ZONES
		_under_construction.visible = on_paved_zone
		# Nothing in a locked zone can be built until the zone itself is
		# bought in the expansion shop, so it gets no "build me" prompt and
		# no price. The bubble in particular has to go: it sits on an
		# absolute z-layer (see CALLOUT_Z_INDEX) and would otherwise float
		# on top of the cloud that's meant to be covering the whole zone.
		if not ZoneProgress.is_unlocked(apron.area_name):
			_callout.visible = false
			if not on_paved_zone:
				draw_colored_polygon(_diamond_points(), COLOR_LOCKED_FALLBACK)
			return
		_set_callout_icon(CALLOUT_CONE_TEXTURE, CALLOUT_CONE_SIZE)
		_callout.visible = true
		if not on_paved_zone:
			draw_colored_polygon(_diamond_points(), COLOR_LOCKED_FALLBACK)
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
		_skin_overlay.texture = load(skin_entry["texture"])
		_skin_overlay.visible = true
	else:
		_skin_overlay.visible = false

	# A pad at the robot airport, holding an aircraft you've flown out. Checked
	# first: robot pads have their own ids, so nothing else can be here.
	var visitor := Fleet.get_aircraft_at_robot_apron(apron.id)
	if visitor:
		if visitor.state == FleetAircraft.State.AWAITING_DEST_CLAIM:
			_set_callout_icon(CALLOUT_DOLLAR_TEXTURE, CALLOUT_DOLLAR_SIZE, Fleet.claim_destination_reward.bind(visitor.id))
		else:
			_set_callout_icon(CALLOUT_DRUM_TEXTURE, CALLOUT_DRUM_SIZE, Fleet.refuel_at_destination.bind(visitor.id))
		_callout.visible = true
	elif not apron.occupied:
		# The free-pad plane bubble means "assign one here", which you can't do
		# at the robot airport - its empty pads are just unused landing slots,
		# so offering the prompt there would invite a blocked action.
		if Maps.current == Maps.ROBOT_MAP:
			_callout.visible = false
		else:
			_set_callout_icon(CALLOUT_PLANE_TEXTURE, CALLOUT_PLANE_SIZE)
			_callout.visible = true
	else:
		var a := Fleet.get_aircraft_at_apron(apron.id)
		var state: int = a.state if a else -1
		match state:
			FleetAircraft.State.PARKED:
				_set_callout_icon(CALLOUT_DRUM_TEXTURE, CALLOUT_DRUM_SIZE, Fleet.fuel_and_depart.bind(a.id))
				_callout.visible = true
			FleetAircraft.State.AWAITING_DEST_CLAIM, FleetAircraft.State.AWAITING_DEST_REFUEL:
				# The aircraft isn't here - it's sitting at the robot airport.
				# This is its home pad, so it shows the way there instead of the
				# reward/fuel bubble it would show if the plane were present.
				_set_callout_arrived(Maps.travel_to.bind(Maps.ROBOT_MAP))
				_callout.visible = true
			FleetAircraft.State.AWAITING_HOME_CLAIM:
				_set_callout_icon(CALLOUT_DOLLAR_TEXTURE, CALLOUT_DOLLAR_SIZE, Fleet.claim_home_reward.bind(a.id))
				_callout.visible = true
			FleetAircraft.State.AWAITING_HOME_REFUEL:
				_set_callout_icon(CALLOUT_DRUM_TEXTURE, CALLOUT_DRUM_SIZE, Fleet.refuel_at_home.bind(a.id))
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
				get_viewport().set_input_as_handled()
				clicked.emit(apron)
