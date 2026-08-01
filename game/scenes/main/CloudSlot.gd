extends Node2D

# Visual + clickable cloud cover for one locked zone. Built entirely in
# code (see setup()) rather than authored in the .tscn, same approach as
# ApronSlot's lock overlay.

signal clicked(area_name: String)

var area_name: String
var _area: Area2D


func setup(p_area_name: String, pos: Vector2) -> void:
	area_name = p_area_name
	position = pos
	z_index = 10  # always drawn (and picked) above ApronSlot's aprons

	var texture: Texture2D = load(CloudLayout.CLOUD_TEXTURES[area_name])
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.centered = true
	add_child(sprite)

	var area := Area2D.new()
	# Off unless the placement tool is open - see set_pickable.
	area.input_pickable = false
	_area = area
	add_child(area)
	for poly in _hit_polygons(texture):
		var cp := CollisionPolygon2D.new()
		cp.polygon = poly
		area.add_child(cp)
	area.input_event.connect(_on_input_event)


# Collision traced from the cloud's own alpha, NOT its texture rectangle.
#
# These crops are big (Zone2's is 1777x936) and mostly empty at the corners,
# and a cloud swallows any click that lands on it. As a rectangle, Zone2's
# cover reached back over the corner of Zone1 and ate the clicks on aprons
# 10, 14, 15 and 20 - pads that are fully visible, in an unlocked zone, with
# nothing drawn over them: the alpha at all four is 0. They simply could not
# be bought.
#
# Tracing the alpha instead means the cover only takes clicks where there is
# actually a cloud. The threshold is deliberately well above zero so the faint
# wisps at the edges (which reach the full width of the crop, so the opaque
# bounding box is no smaller than the rectangle was) don't bring the problem
# straight back.
const HIT_ALPHA := 0.45
const HIT_EPSILON := 12.0


func _hit_polygons(texture: Texture2D) -> Array:
	var image := texture.get_image()
	var bitmap := BitMap.new()
	bitmap.create_from_image_alpha(image, HIT_ALPHA)
	var size := image.get_size()
	var polys := bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), HIT_EPSILON)
	# The sprite is centred, so the traced pixel coordinates need shifting to
	# match it.
	var offset := -Vector2(size) * 0.5
	var out := []
	for poly in polys:
		var shifted := PackedVector2Array()
		for p in poly:
			shifted.append(p + offset)
		out.append(shifted)
	return out


# A cover only needs to take clicks while CloudEditor is placing them; that's
# the only handler that does anything with one. In normal play it must NOT,
# because swallowing a click is exactly how a cover reaches past its own zone
# and blocks pads that are unlocked, visible and buyable - which is what
# happened to Zone1's aprons 10, 14, 15 and 20 under the Zone2 cover.
#
# Tracing the alpha (see _hit_polygons) shrank that reach a great deal, but it
# can't remove it: the Zone2 and Forest covers still genuinely overlap pads in
# DarkZone and Snow, so buying zones out of order would bring the same bug
# straight back. Not taking the click at all is what actually fixes it.
#
# Clicking a locked zone's pad now opens the apron panel, which says the zone
# is locked and where to buy it - better than a click that does nothing.
func set_pickable(value: bool) -> void:
	if is_instance_valid(_area):
		_area.input_pickable = value


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit(area_name)
