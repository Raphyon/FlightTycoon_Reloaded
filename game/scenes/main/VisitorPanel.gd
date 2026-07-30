extends Control

# "Who you're visiting" - shown only while you're standing in someone else's
# airport. Built from art rather than a styled panel: board_friendhome is
# flush-left and rounded on the right, so it's meant to butt against the screen
# edge the way the other HUD boards do.
#
# Its contents come from the map's own "visiting" entry (see Maps), so a second
# visitable airport needs no code here - just that key.
const BOARD := preload("res://assets/board/board_friendhome@ipad.png")
const FRAME := preload("res://assets/player_avatar/avatar_frame@2x.png")
# One per unit of distance to this destination - the same number that sets the
# flight time (see Fleet.flight_seconds_to). Cut from the hangar's "busy" tab,
# the only cloud in the dump at icon scale (tools/cloud_icon.py).
const CLOUD := preload("res://assets/bubbles/cloud_icon@2x.png")

const BOARD_SIZE := Vector2(276, 95)
# The framed avatar is 112x102 natively, taller than the 95px board. Scaled to
# sit inside it with a couple of pixels of overhang top and bottom, which is
# how the reference reads.
const FRAME_SIZE := Vector2(104, 95)
const FRAME_POS := Vector2(4, 0)
# The portrait sits inside the frame's raised border, not flush to its edge.
const AVATAR_INSET := Vector2(13, 12)

const TEXT_LEFT := 116.0
const NAME_Y := 6.0
const CLOUD_Y := 38.0
const LEVEL_Y := 58.0
const CLOUD_SIZE := Vector2(23, 16)
const CLOUD_GAP := 3.0
const FONT_SIZE := 21
const OUTLINE := 6

var _name_label: Label
var _level_label: Label
var _avatar: TextureRect
var _clouds: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = BOARD_SIZE
	size = BOARD_SIZE
	_build()
	Maps.map_changed.connect(func(_k: String) -> void: _refresh())
	_refresh()


func _build() -> void:
	var board := TextureRect.new()
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.texture = BOARD
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	# The frame is an opaque plate, not a border overlay, so it goes down first
	# and the portrait sits on top of it - the other way round and the plate
	# simply covers the artwork.
	var frame := TextureRect.new()
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	frame.texture = FRAME
	frame.position = FRAME_POS
	frame.size = FRAME_SIZE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(frame)

	_avatar = TextureRect.new()
	_avatar.position = FRAME_POS + AVATAR_INSET
	_avatar.size = FRAME_SIZE - AVATAR_INSET * 2.0
	_avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_avatar)

	_name_label = _label(NAME_Y)
	_clouds = Control.new()
	_clouds.position = Vector2(TEXT_LEFT, CLOUD_Y)
	_clouds.size = Vector2(BOARD_SIZE.x - TEXT_LEFT - 12.0, CLOUD_SIZE.y)
	_clouds.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_clouds)
	_level_label = _label(LEVEL_Y)


func _label(y: float) -> Label:
	var l := Label.new()
	l.position = Vector2(TEXT_LEFT, y)
	l.size = Vector2(BOARD_SIZE.x - TEXT_LEFT - 12.0, 30)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", FONT_SIZE)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.11, 0.06, 0.02, 1))
	l.add_theme_constant_override("outline_size", OUTLINE)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	return l


func _refresh() -> void:
	var info: Dictionary = Maps.entry().get("visiting", {})
	visible = not info.is_empty()
	if not visible:
		return
	_name_label.text = str(info.get("name", ""))
	_level_label.text = "Lv.%d" % int(info.get("level", 1))
	var avatar_path: String = info.get("avatar", "")
	if avatar_path != "":
		_avatar.texture = load(avatar_path)
	_rebuild_clouds(Fleet.distance_to(Maps.current))


# Distance drawn as a centred row of clouds, one per unit.
func _rebuild_clouds(distance: int) -> void:
	for child in _clouds.get_children():
		child.queue_free()
	var total := distance * CLOUD_SIZE.x + maxf(0.0, distance - 1) * CLOUD_GAP
	var x := (_clouds.size.x - total) * 0.5
	for i in range(distance):
		var c := TextureRect.new()
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.texture = CLOUD
		c.position = Vector2(x + i * (CLOUD_SIZE.x + CLOUD_GAP), 0.0)
		c.size = CLOUD_SIZE
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_clouds.add_child(c)
