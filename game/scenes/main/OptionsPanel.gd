extends Control

# Game options, opened from the gear in the HUD's top-right corner.
#
# Deliberately short. There is no audio system, so there are no volume sliders
# to fake - everything listed here does something. It will grow as the game
# does; what it must not become is a wall of switches that mostly lie.
#
# Built on board_changelist@ipad, positioned as fractions of the board and
# multiplied by BOARD_SCALE, the same way RoutePickerPanel and ApronInfoPanel
# are - so resizing the dialog is one number.
const BOARD := preload("res://assets/board/board_changelist@ipad.png")
const BUTTON_TEXTURE := preload("res://assets/buttons/button_orange2@2x.png")
const WIDE_BUTTON_TEXTURE := preload("res://assets/buttons/button_orange4@2x.png")
const DANGER_TEXTURE := preload("res://assets/buttons/button_red1@2x.png")
const DANGER_PRESSED := preload("res://assets/buttons/button_red2@2x.png")

const BOARD_NATIVE := Vector2(943, 452)
const BOARD_SCALE := 0.72
const BOARD_SIZE := Vector2(679, 325)

const TITLE_Y := 0.055
const ROW_X := 0.09
const ROW_W := 0.82
const FIRST_ROW_Y := 0.24
const ROW_STEP := 0.17

const FONT_TITLE := 26
const FONT_ROW := 17
const FONT_BUTTON := 15
const FONT_NOTE := 13

var _content: Control
var _rows: Array = []
# Two-step, because this one is not undoable. First press arms it, second does
# it, and anything else disarms - see _arm_reset.
var _reset_armed := false
var _reset_button: TextureButton
var _reset_label: Label
var _reset_note: Label


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
	_build()


func _px(fx: float, fy: float) -> Vector2:
	return Vector2(BOARD_SIZE.x * fx, BOARD_SIZE.y * fy)


func _fs(native: int) -> int:
	return maxi(9, roundi(native * BOARD_SCALE))


func _build() -> void:
	var title := _label("Options", _fs(FONT_TITLE), HORIZONTAL_ALIGNMENT_CENTER)
	title.position = _px(0.0, TITLE_Y)
	title.size = _px(1.0, 0.12)

	_add_row(0, "Fullscreen", _fullscreen_caption(), _on_fullscreen_pressed)

	# The destructive one goes last and looks different - red art, and it says
	# what it will destroy before you can press it twice.
	var row := _add_row(1, "Reset game data", "Reset...", _on_reset_pressed, DANGER_TEXTURE)
	_reset_button = row[0]
	_reset_label = row[1]
	_reset_note = _label("", _fs(FONT_NOTE), HORIZONTAL_ALIGNMENT_LEFT)
	_reset_note.position = _px(ROW_X, FIRST_ROW_Y + ROW_STEP + 0.105)
	_reset_note.size = _px(ROW_W, 0.09)
	_reset_note.add_theme_color_override("font_color", Color(0.95, 0.82, 0.72))
	_set_reset_note()

	CloseButton.add_to(self, BOARD_SIZE, _close)


# label on the left, button on the right, one line each.
func _add_row(index: int, text: String, caption: String, action: Callable,
		texture: Texture2D = BUTTON_TEXTURE) -> Array:
	var y := FIRST_ROW_Y + ROW_STEP * index

	# Drawn at the texture's own aspect - see ApronInfoPanel._button for why
	# every button in this project computes width rather than being given one.
	# 1x NATIVE: the button art is @2x, so half its pixels is its intended size.
	var h: float = texture.get_height() * 0.5
	var w: float = texture.get_width() * 0.5

	# The row label matches the BUTTON's height, not a board fraction, or the
	# two stop sharing a centre line the moment the button size changes.
	var l := _label(text, _fs(FONT_ROW), HORIZONTAL_ALIGNMENT_LEFT)
	l.position = _px(ROW_X, y)
	l.size = Vector2(BOARD_SIZE.x * ROW_W * 0.55, h)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var b := TextureButton.new()
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = texture
	b.size = Vector2(w, h)
	b.position = Vector2(BOARD_SIZE.x * (ROW_X + ROW_W) - w, BOARD_SIZE.y * y)
	b.pressed.connect(action)
	add_child(b)

	var cap := Label.new()
	cap.text = caption
	cap.add_theme_font_size_override("font_size", _fs(FONT_BUTTON))
	cap.add_theme_color_override("font_color", Color(0.26, 0.13, 0.02, 1))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cap.set_anchors_preset(Control.PRESET_FULL_RECT)
	cap.anchor_right = 1.0
	cap.anchor_bottom = 1.0
	b.add_child(cap)

	_rows.append({"button": b, "caption": cap})
	return [b, cap]


func _label(text: String, size_px: int, align: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l


func open() -> void:
	_disarm_reset()
	move_to_front()
	visible = true
	_refresh()


func _close() -> void:
	_disarm_reset()
	visible = false


func _refresh() -> void:
	if _rows.size() > 0:
		(_rows[0]["caption"] as Label).text = _fullscreen_caption()


func _fullscreen_caption() -> String:
	var mode := DisplayServer.window_get_mode()
	var full := (mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	return "On" if full else "Off"


func _on_fullscreen_pressed() -> void:
	_disarm_reset()
	var mode := DisplayServer.window_get_mode()
	var full := (mode == DisplayServer.WINDOW_MODE_FULLSCREEN
		or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	_refresh()


# First press arms, second press does it. A one-tap wipe next to a fullscreen
# toggle is a trap - and this one throws away a playthrough with no undo.
func _on_reset_pressed() -> void:
	if not _reset_armed:
		_arm_reset()
		return
	_disarm_reset()
	SaveGame.reset_to_defaults()
	visible = false


func _arm_reset() -> void:
	_reset_armed = true
	_reset_button.texture_normal = DANGER_PRESSED
	_reset_label.text = "Confirm"
	_set_reset_note()


func _disarm_reset() -> void:
	if not _reset_armed:
		_set_reset_note()
		return
	_reset_armed = false
	if is_instance_valid(_reset_button):
		_reset_button.texture_normal = DANGER_TEXTURE
		_reset_label.text = "Reset..."
	_set_reset_note()


# Says exactly what goes and what stays, because "reset" on its own does not
# distinguish between a playthrough and the hand-placed level it runs on.
func _set_reset_note() -> void:
	if not is_instance_valid(_reset_note):
		return
	_reset_note.text = ("Press again to erase money, fleet, pads, zones and buildings."
		if _reset_armed
		else "Clears your progress. Placed pads, plots and routes are kept.")
