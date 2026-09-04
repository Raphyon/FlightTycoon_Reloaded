extends Node2D

# One construction site. Empty, it shows the cone callout the aprons use for an
# unbuilt pad - same visual language, because it means the same thing: tap here
# to build something. Once bought it shows the building instead.
#
# Position is the point where the base meets the ground, which is what
# the placement tool placed, so the sprite hangs UP and LEFT from it rather than
# being centred on it.

signal clicked(plot_id: int)
# Tapping the BUILDING rather than its bubble - "show me this site", not "act on
# it". Mirrors the aprons exactly: the callout is the button, the thing under it
# opens the menu. Only fires on a site that has something standing on it; an
# empty one has nothing to show that its cone does not already offer.
signal body_clicked(plot_id: int)

# One-piece callouts. These used to be a bubble sprite with an icon sprite
# positioned on top, which never sat quite centred - two independently placed
# things that only LOOK like one. The art now includes the icon, so there is
# nothing to align.
#
# Drawn at their native 42x49: that is the real extent of the art (the source
# is a 1024 canvas that is mostly padding), so scaling up would just soften it.
# What an empty plot looks like: a construction site rather than bare ground
# with a bubble floating over nothing. Which variant it uses is the plot's own
# "site" field - see BuildingLayout.SITE_TEXTURES.
# THE PLOT COORDINATE IS NOT QUITE THE BLOCK'S CORNER, so the sprite is nudged
# to sit in its block rather than beside it.
#
# The road-bounded block was flood-filled straight out of the background art at
# every one of the 42 plots - it comes out 200x100, ratio 2.00, which is what
# TARGET_WIDTH is set against. Its bottom vertex sits a few pixels off the plot
# every time, and always the same way: dx -3.8 +/- 1.0, dy +1.1 +/- 0.9. So a
# building drawn at the plot lands slightly right of its block and opens a
# sliver of tarmac along the lower-LEFT edge.
#
# One constant covers all 42 because the spread is under a pixel. -6 rather than
# the measured -3.8 because that is what read best against the art; the extra
# 2px is inside the noise and the grass edge is inset from the sprite's alpha.
#
# NOT a fix to the plot data - the plots are hand-placed level data and are
# consistent with each other. This is registration between two coordinate
# conventions, so it belongs at the draw call.
const BLOCK_NUDGE := Vector2(-6, 1)

const CALLOUT_CONE := preload("res://assets/bubbles/cone_bubble@2x.png")
const CALLOUT_CASH := preload("res://assets/bubbles/cash_bubble@2x.png")
# The swoop the aprons use, for the same reason: collecting rent should look
# like collecting rent rather than like a number changing.
const SWOOP_EARNING := preload("res://assets/bubbles/earning_bubble@2x.png")
# A plot under scaffolding gets the same countdown an aircraft in the air does -
# same bubble, same bar. It is the same question: how long until this is worth
# something again.
#
# The cone, not the fuel drum: it is the same language the empty-plot callout
# already speaks, where a cone means work is happening here.
const TAG_UPGRADING := preload("res://assets/bubbles/construction_bubble@2x.png")
const CALLOUT_LIGHTS := preload("res://assets/bubbles/lights_bubble@2x.png")
# What a building with its lights off looks like: dimmed and cooled, not
# greyed. A flat grey reads as disabled UI; this reads as dusk.
const DARK_MODULATE := Color(0.62, 0.66, 0.78, 1.0)
# How far above the plot's ground point the callout floats - FIXED, and the
# same whatever is standing there.
#
# It used to be derived from the building's own height, so the cone on an empty
# site sat at 70 and a Grand Hotel's cash bubble at 242. The callout jumped up
# the moment you built, and every plot's bubble sat somewhere different. A
# bubble is a button; buttons do not move.
#
# Tall buildings therefore overlap it, which is what CALLOUT_Z_INDEX is for -
# the callout draws over its own building rather than being swallowed by it.
const CALLOUT_LIFT := 70.0
const CALLOUT_Z_INDEX := 100

var plot_id: int = -1
var site_type: String = "buildings"

var _sprite: Sprite2D
var _bubble: Sprite2D
var _area: Area2D
var _shape: CollisionShape2D
var _body_shape: CollisionShape2D
# See _on_input_event - two shapes means two callbacks for one tap.
var _last_click_frame := -1
var _swoop: ProgressBubble
var _tag: ProgressBubble


func setup(id: int, pos: Vector2, site: String = "buildings") -> void:
	plot_id = id
	site_type = site
	position = pos
	name = "BuildingSlot%d" % id

	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)

	_bubble = Sprite2D.new()
	# Over its own building, and over the one behind it - y_sort on the parent
	# would otherwise let a nearer building cover this one's callout.
	_bubble.z_index = CALLOUT_Z_INDEX
	_bubble.z_as_relative = false
	add_child(_bubble)

	_area = Area2D.new()
	_area.input_pickable = true
	_shape = CollisionShape2D.new()
	_area.add_child(_shape)
	# A second shape over the building itself. Separate from the bubble's, not a
	# union of the two, because the two mean different things and a union rect
	# would also swallow the empty air between them.
	_body_shape = CollisionShape2D.new()
	_area.add_child(_body_shape)
	add_child(_area)
	_area.input_event.connect(_on_input_event)

	_swoop = ProgressBubble.new()
	_swoop.z_index = CALLOUT_Z_INDEX
	_swoop.z_as_relative = false
	_swoop.visible = false
	add_child(_swoop)
	ProgressBubble.place_by_tail(_swoop, Vector2(0, -CALLOUT_LIFT))
	_swoop.completed.connect(func() -> void:
		_swoop.visible = false
		refresh()
	)

	_tag = ProgressBubble.new()
	_tag.z_index = CALLOUT_Z_INDEX
	_tag.z_as_relative = false
	_tag.visible = false
	add_child(_tag)
	ProgressBubble.place_by_tail(_tag, Vector2(0, -CALLOUT_LIFT))
	BuildingProgress.upgrade_changed.connect(func(id: int) -> void:
		if id == plot_id:
			refresh())

	refresh()


# Re-reads what's built here and whether its rent is up. Called on setup, when
# BuildingProgress changes, and on the slow tick that watches timers - so this
# has to stay cheap.
func refresh() -> void:
	var key := BuildingProgress.building_at(plot_id)
	var empty := key == ""

	if empty:
		var site_path := BuildingLayout.site_texture_path(site_type)
		_sprite.texture = load(site_path) if ResourceLoader.exists(site_path) else null
	else:
		var path := BuildingLayout.texture_path(key)
		_sprite.texture = load(path) if ResourceLoader.exists(path) else null

	if _sprite.texture:
		var w: float = _sprite.texture.get_width()
		var h: float = _sprite.texture.get_height()
		_sprite.offset = Vector2(-w * 0.5, -h) + BLOCK_NUDGE

	# UNDER SCAFFOLDING: no rent callout at all, a countdown instead. The
	# building is off service until it finishes, so a cash bubble would be
	# offering something that is not there.
	var upgrading := not empty and BuildingProgress.is_upgrading(plot_id)
	if upgrading:
		_bubble.visible = false
		_rebuild_hit_area(false)
		_rebuild_body_area(true)
		_show_upgrade_tag()
		return
	_hide_upgrade_tag()

	# LIGHTS OUT TAKES THE BUBBLE. There is only one callout per site, and a
	# dark building is the more urgent of the two - rent keeps waiting whether
	# or not it is collected now, and relighting immediately hands the cash
	# bubble back if rent was ready. Two taps, two rewards, in that order.
	# The OFFER, not merely being dark - a lapsed one shows no bubble.
	var dark := not empty and BuildingProgress.lights_offer_open(plot_id)
	_sprite.modulate = DARK_MODULATE if dark else Color.WHITE

	# Cone on an empty site, cash on one with rent waiting, nothing while a
	# building is still earning - the same three-state callout the aprons use.
	var ready := not empty and BuildingProgress.is_rent_ready(plot_id)
	var show_callout := empty or ready or dark
	_bubble.visible = show_callout
	if show_callout:
		if dark:
			_bubble.texture = CALLOUT_LIGHTS
		else:
			_bubble.texture = CALLOUT_CONE if empty else CALLOUT_CASH
		_bubble.position = Vector2(0, -CALLOUT_LIFT - _bubble.texture.get_height() * 0.5)

	_rebuild_hit_area(show_callout)
	_rebuild_body_area(not empty)


# THE BUBBLE IS THE ONLY HIT AREA. Not the building.
#
# It used to be the whole sprite, which made a Grand Hotel a 200x224 button -
# so brushing the roof of something you had already paid for collected its
# rent, and there was no way to click a building without acting on it. The
# aprons have always worked this way (ApronSlot._input tests the bubble rect
# before firing, and a tap on the pad itself opens the apron menu instead), and
# this now matches: the callout is the button, the building is scenery.
#
# With no callout up there is nothing to press, so the area goes away entirely
# rather than sitting there silently swallowing clicks.
func _show_upgrade_tag() -> void:
	if not is_instance_valid(_tag):
		return
	_tag.show_status(TAG_UPGRADING,
		Fleet.time_left_text(BuildingProgress.upgrade_seconds_left(plot_id)),
		BuildingProgress.upgrade_progress(plot_id), true)
	set_process(true)


func _hide_upgrade_tag() -> void:
	if not is_instance_valid(_tag):
		return
	_tag.visible = false
	set_process(false)


# Ticks the countdown in place rather than refreshing the whole slot, which
# would reload the sprite and rebuild both hit areas once a frame.
func _process(_delta: float) -> void:
	if plot_id < 0 or not BuildingProgress.is_upgrading(plot_id):
		set_process(false)
		refresh()
		return
	_tag.show_status(TAG_UPGRADING,
		Fleet.time_left_text(BuildingProgress.upgrade_seconds_left(plot_id)),
		BuildingProgress.upgrade_progress(plot_id), true)


func _rebuild_hit_area(has_callout: bool) -> void:
	if not has_callout or _bubble.texture == null:
		_shape.disabled = true
		return
	_shape.disabled = false
	var r := RectangleShape2D.new()
	r.size = Vector2(_bubble.texture.get_width(), _bubble.texture.get_height())
	_shape.shape = r
	_shape.position = _bubble.position


# The building's own footprint, live only once something is standing here. This
# is what makes demolition reachable: a built site whose rent is not up yet has
# no callout at all, so without this there is no way to touch it again, ever.
func _rebuild_body_area(built: bool) -> void:
	if not built or _sprite.texture == null:
		_body_shape.disabled = true
		return
	_body_shape.disabled = false
	var w: float = _sprite.texture.get_width()
	var h: float = _sprite.texture.get_height()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	# The sprite hangs up and left from the ground point (see setup), so its
	# centre is half a width left and half a height up.
	_body_shape.shape = r
	_body_shape.position = Vector2(0.0, -h * 0.5)


func set_pickable(on: bool) -> void:
	if is_instance_valid(_area):
		_area.input_pickable = on


# Which of the two things was hit. The bubble wins where they overlap - a tall
# building draws behind its own callout, and the callout is the button.
#
# ONE CLICK, ONE CALLBACK. An Area2D fires input_event once PER SHAPE hit, and
# the callout floats inside a tall building's own footprint, so a tap on the
# bubble hits both shapes and calls this twice. The first call collected the
# rent, which refreshed the slot and hid the bubble; the second call then found
# no bubble, fell through, and opened the demolition menu behind it. The frame
# guard is what makes the second call a no-op - without it the routing is
# correct and the STATE has already moved underneath it.
# Rent gets the two second swoop the aprons use. An EMPTY site's cone does not:
# it opens the Prop Shop, and there is nothing being done to watch.
func _claim() -> void:
	# Same order the bubble is drawn in: the lights come first.
	if BuildingProgress.is_built(plot_id) and BuildingProgress.lights_offer_open(plot_id):
		_bubble.visible = false
		_shape.disabled = true
		_swoop.visible = true
		_swoop.run(SWOOP_EARNING, "Lighting",
			func() -> void: BuildingProgress.relight(plot_id))
		return
	if not BuildingProgress.is_built(plot_id) or not BuildingProgress.is_rent_ready(plot_id):
		clicked.emit(plot_id)
		return
	# Hide the button for the duration, so one site cannot be tapped into two
	# swoops for one rent cycle.
	_bubble.visible = false
	_shape.disabled = true
	_swoop.visible = true
	# ONE TAP TAKES THE WHOLE AIRPORT'S RENT. Collecting was a lap of the board
	# - 42 plots, each its own tap on a site you had to find first - and the
	# collecting had outgrown the deciding. Lights are deliberately NOT included:
	# they are a thing you catch, and sweeping them from a rent tap would remove
	# the only reason to look at the board.
	_swoop.run(SWOOP_EARNING, "Claiming",
		func() -> void: BuildingProgress.collect_all())


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed
			and event.button_index == MOUSE_BUTTON_LEFT):
		return
	# Same guard ApronSlot needs: a panel over the world must swallow the click.
	if get_viewport().gui_get_hovered_control() != null:
		return
	var frame := Engine.get_process_frames()
	if frame == _last_click_frame:
		return
	_last_click_frame = frame
	if _bubble.visible and _bubble.texture and not _shape.disabled:
		var half := Vector2(_bubble.texture.get_width(), _bubble.texture.get_height()) * 0.5
		var local := to_local(get_global_mouse_position())
		if Rect2(_bubble.position - half, half * 2.0).has_point(local):
			_claim()
			return
	if not _body_shape.disabled:
		body_clicked.emit(plot_id)
