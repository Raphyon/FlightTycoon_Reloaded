class_name EditorHud
extends CanvasLayer

# Shared on-screen readout for the in-game placement tools.
#
# They all want the same thing: a dark panel of plain text pinned top-left,
# visible only while that tool is active. RotorEditor and PathEditor had each
# grown a byte-identical copy of it, and the apron and cloud editors had none
# at all - they only printed to the console, which is invisible when the game
# is running fullscreen, so you were placing tiles with no idea which area was
# selected.
#
# Children are built in _init rather than _ready so set_lines() is safe to call
# immediately after create(), without depending on tree-entry order.
const LAYER := 50
const MARGIN := Vector2(12, 12)
const FONT_SIZE := 14
const BG_COLOR := Color(0, 0, 0, 0.7)

var _label: Label


static func create(parent: Node) -> EditorHud:
	var hud := EditorHud.new()
	parent.add_child(hud)
	return hud


func _init() -> void:
	layer = LAYER
	visible = false

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = MARGIN
	var style := StyleBoxFlat.new()
	style.bg_color = BG_COLOR
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	panel.add_child(_label)


# Show the panel with these lines, or hide it entirely when `active` is false.
func set_lines(active: bool, lines: Array) -> void:
	visible = active
	if active:
		_label.text = "\n".join(lines)
