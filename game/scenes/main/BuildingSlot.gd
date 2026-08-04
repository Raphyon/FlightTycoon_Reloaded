extends Node2D

# One construction site. Empty, it shows the cone callout the aprons use for an
# unbuilt pad - same visual language, because it means the same thing: tap here
# to build something. Once bought it shows the building instead.
#
# Position is the point where the base meets the ground, which is what
# BuildingEditor places, so the sprite hangs UP and LEFT from it rather than
# being centred on it.

signal clicked(plot_id: int)

const CALLOUT_BUBBLE := preload("res://assets/bubbles/callout_bubble@2x.png")
const CALLOUT_CONE := preload("res://assets/bubbles/cone_icon@2x.png")
const CONE_SIZE := Vector2(30, 30)
const BUBBLE_SIZE := Vector2(58, 62)
# How far above the ground point the callout floats on an empty site. Nothing
# is drawn there, so it needs its own height rather than sitting on a sprite.
const EMPTY_CALLOUT_LIFT := 70.0
# Clickable radius of an empty site, which has no art to hit-test against.
const EMPTY_RADIUS := 44.0

var plot_id: int = -1

var _sprite: Sprite2D
var _bubble: Sprite2D
var _icon: Sprite2D
var _area: Area2D
var _shape: CollisionShape2D


func setup(id: int, pos: Vector2) -> void:
	plot_id = id
	position = pos
	name = "BuildingSlot%d" % id

	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)

	_bubble = Sprite2D.new()
	_bubble.texture = CALLOUT_BUBBLE
	_bubble.scale = BUBBLE_SIZE / Vector2(CALLOUT_BUBBLE.get_width(), CALLOUT_BUBBLE.get_height())
	add_child(_bubble)

	_icon = Sprite2D.new()
	_icon.texture = CALLOUT_CONE
	_icon.scale = CONE_SIZE / Vector2(CALLOUT_CONE.get_width(), CALLOUT_CONE.get_height())
	add_child(_icon)

	_area = Area2D.new()
	_area.input_pickable = true
	_shape = CollisionShape2D.new()
	_area.add_child(_shape)
	add_child(_area)
	_area.input_event.connect(_on_input_event)

	refresh()


# Re-reads what's built here. Called on setup and whenever BuildingProgress
# changes, so buying redraws this slot without rebuilding every other one.
func refresh() -> void:
	var key := BuildingProgress.building_at(plot_id)
	var empty := key == ""

	if empty:
		_sprite.texture = null
	else:
		var path := BuildingLayout.texture_path(key)
		_sprite.texture = load(path) if ResourceLoader.exists(path) else null

	if _sprite.texture:
		var w: float = _sprite.texture.get_width()
		var h: float = _sprite.texture.get_height()
		_sprite.offset = Vector2(-w * 0.5, -h)

	# The callout marks an empty site; a built one has nothing to say yet (rent
	# collection will go here once buildings actually earn).
	_bubble.visible = empty
	_icon.visible = empty
	if empty:
		_bubble.position = Vector2(0, -EMPTY_CALLOUT_LIFT)
		_icon.position = _bubble.position + Vector2(0, -2)

	_rebuild_hit_area(empty)


# An empty site is a plain circle at the ground point. A built one takes its
# own footprint, so a tall building is clickable up its whole height rather
# than only where it meets the ground.
func _rebuild_hit_area(empty: bool) -> void:
	if empty or _sprite.texture == null:
		var c := CircleShape2D.new()
		c.radius = EMPTY_RADIUS
		_shape.shape = c
		_shape.position = Vector2(0, -EMPTY_CALLOUT_LIFT * 0.5)
		return
	var w: float = _sprite.texture.get_width()
	var h: float = _sprite.texture.get_height()
	var r := RectangleShape2D.new()
	r.size = Vector2(w, h)
	_shape.shape = r
	_shape.position = Vector2(0, -h * 0.5)


func set_pickable(on: bool) -> void:
	if is_instance_valid(_area):
		_area.input_pickable = on


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(plot_id)
