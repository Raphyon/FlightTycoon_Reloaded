extends Control

# What you get when you click a friend in the list: their card, and what you
# can do about them.
#
# board_friend_info is one baked image - frame, background, the ring and the
# blue card are all painted in - so this only lays the friend's own contents
# over the card that's already there, plus the buttons underneath.
const BOARD := preload("res://assets/board/board_friend_info@2x.png")
const VISIT_TEXTURE := preload("res://assets/buttons/button_orange2@2x.png")
const REMOVE_NORMAL := preload("res://assets/buttons/button_red1@2x.png")
const REMOVE_PRESSED := preload("res://assets/buttons/button_red2@2x.png")

const BOARD_SIZE := Vector2(878, 422)
# Where the card sits inside the artwork, measured off the image rather than
# guessed - the blue region runs x304-563, y25-320.
const CARD_RECT := Rect2(304, 25, 260, 296)

# 1x NATIVE - the art is 136x62 @2x, so this was drawing it at double size.
const BUTTON_SIZE := Vector2(68, 31)
const BUTTON_Y := 336.0
const BUTTON_GAP := 40.0
const BUTTON_FONT := 18
const DISABLED_MODULATE := Color(0.55, 0.55, 0.55, 1.0)

var _map_key := ""
var _contents: Control
var _visit_button: TextureButton
var _remove_button: TextureButton
var _remove_label: Label


func _ready() -> void:
	visible = false
	custom_minimum_size = BOARD_SIZE
	size = BOARD_SIZE
	_build()


func _build() -> void:
	var board := TextureRect.new()
	board.texture = BOARD
	board.size = BOARD_SIZE
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	# Rebuilt per friend, so it lives in its own node that can be emptied.
	_contents = Control.new()
	_contents.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_contents)

	var total := BUTTON_SIZE.x * 2.0 + BUTTON_GAP
	var left := (BOARD_SIZE.x - total) * 0.5

	_visit_button = _button(VISIT_TEXTURE, VISIT_TEXTURE, Vector2(left, BUTTON_Y))
	_visit_button.pressed.connect(_on_visit)
	add_child(_visit_button)
	_visit_button.add_child(_button_label("Visit"))

	_remove_button = _button(REMOVE_NORMAL, REMOVE_PRESSED,
		Vector2(left + BUTTON_SIZE.x + BUTTON_GAP, BUTTON_Y))
	_remove_button.pressed.connect(_on_remove)
	add_child(_remove_button)
	_remove_label = _button_label("Remove")
	_remove_button.add_child(_remove_label)


func _button(normal: Texture2D, pressed: Texture2D, pos: Vector2) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = normal
	b.texture_pressed = pressed
	b.texture_hover = pressed
	b.position = pos
	b.size = BUTTON_SIZE
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	return b


func _button_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.size = BUTTON_SIZE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", BUTTON_FONT)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.25, 0.10, 0.02, 1))
	l.add_theme_constant_override("outline_size", 5)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func show_friend(map_key: String) -> void:
	_map_key = map_key
	for child in _contents.get_children():
		child.queue_free()
	FriendCard.populate(_contents, map_key, CARD_RECT)

	# The robot can't be unfriended - your dispatched aircraft land there. The
	# button stays visible but dead, so the rule is legible rather than the
	# option just being absent.
	var removable := Friends.can_remove(map_key)
	_remove_button.disabled = not removable
	_remove_button.modulate = Color.WHITE if removable else DISABLED_MODULATE
	_remove_label.text = "Remove" if removable else "Can't remove"
	visible = true


func _on_visit() -> void:
	visible = false
	get_parent().get_node("FriendsPanel").visible = false
	Maps.travel_to(_map_key)


func _on_remove() -> void:
	if Friends.remove(_map_key):
		visible = false
