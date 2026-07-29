extends Node2D

# Visual + clickable cloud cover for one locked zone. Built entirely in
# code (see setup()) rather than authored in the .tscn, same approach as
# ApronSlot's lock overlay.

signal clicked(area_name: String)

var area_name: String


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
	area.input_pickable = true
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = texture.get_size()
	shape.shape = rect
	area.add_child(shape)
	add_child(area)
	area.input_event.connect(_on_input_event)


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		clicked.emit(area_name)
