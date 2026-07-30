class_name BackButton
extends RefCounted

# The arrow every full-screen panel in the reference has, bottom-right, over a
# "Back" caption. Replaces the full-width Close bar those panels grew.
#
# Built here rather than per panel so the seven of them can't drift apart, and
# because it has to hang off Frame: the panels are PanelContainers, which
# override their direct children's anchors to make them fill.
const NORMAL := preload("res://assets/buttons/button_back@2x.png")
const PRESSED := preload("res://assets/buttons/button_back2@2x.png")

const SIZE := Vector2(80, 80)
# The bottom margin clears the cabin floor rather than hugging the screen edge:
# bigplane2's brown interior ends at 0.766 of its height, and everything below
# that is seat backs, so an arrow at the true bottom sits on the furniture.
# Measured, not eyeballed - 0.234 * 720 is ~169px.
const MARGIN := Vector2(34, 176)
const CAPTION_HEIGHT := 24.0
const CAPTION_FONT := 15


static func add_to(frame: Control, on_pressed: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.name = "BackButton"
	# ignore_texture_size before the texture, or `size` clamps up to the art.
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = NORMAL
	button.texture_pressed = PRESSED
	button.texture_hover = PRESSED
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	button.offset_left = -(SIZE.x + MARGIN.x)
	button.offset_right = -MARGIN.x
	button.offset_top = -(SIZE.y + CAPTION_HEIGHT + MARGIN.y)
	button.offset_bottom = -(CAPTION_HEIGHT + MARGIN.y)
	button.pressed.connect(on_pressed)
	frame.add_child(button)

	var caption := Label.new()
	caption.text = "Back"
	caption.position = Vector2(0.0, SIZE.y)
	caption.size = Vector2(SIZE.x, CAPTION_HEIGHT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", CAPTION_FONT)
	caption.add_theme_color_override("font_color", Color.WHITE)
	caption.add_theme_color_override("font_outline_color", Color(0.20, 0.09, 0.02, 1))
	caption.add_theme_constant_override("outline_size", 5)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(caption)
	return button
