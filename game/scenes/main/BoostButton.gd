extends Control

# The way into the boost panel: one card at the edge of the screen, there ONLY
# while you hold something or something is running.
#
# The toolbar was the obvious home and is the wrong one - every button on that
# shelf is a piece of art with its own pressed state, and there is none for
# this. The boost icons are already button-shaped, a gold frame with a glyph in
# it, so the card is the button. A control that is not there when it has nothing
# to say costs no screen and needs no art.

const ICON := preload("res://assets/boosts/boost_collect_2x.png")
const SIZE := Vector2(52, 52)
const BADGE_FONT := 12

var _button: TextureButton
var _badge: Label


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_button = TextureButton.new()
	_button.focus_mode = Control.FOCUS_NONE
	# Before the texture, or the art's own size becomes the minimum and the
	# size below is silently clamped up to it.
	_button.ignore_texture_size = true
	_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_button.texture_normal = ICON
	_button.custom_minimum_size = SIZE
	_button.size = SIZE
	_button.pressed.connect(_open)
	add_child(_button)

	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", BADGE_FONT)
	_badge.add_theme_color_override("font_color", Color(1, 0.97, 0.86))
	_badge.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_badge.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.size = SIZE
	add_child(_badge)

	Boosts.inventory_changed.connect(_refresh)
	Boosts.boost_started.connect(func(_k: String, _s: float) -> void: _refresh())
	Boosts.boost_ended.connect(func(_k: String) -> void: _refresh())
	Maps.map_changed.connect(func(_m: String) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	var held := Boosts.total_held()
	var running := Boosts.autoturn_active() or Boosts.is_active("speed") \
		or Boosts.is_active("cash") or Boosts.is_active("fuel")
	# Nothing held and nothing running means nothing to say, so it goes away
	# entirely rather than sitting there greyed out.
	visible = (held > 0 or running) and not Maps.is_robot_map()
	_badge.text = str(held) if held > 0 else ""
	# Lit while something is running, so the state is readable without opening
	# anything - the same reason a pad shows its own countdown.
	_button.modulate = Color(1, 1, 1) if running else Color(0.82, 0.80, 0.78)


func _open() -> void:
	var panel: Control = get_node_or_null("../BoostPanel")
	if panel:
		panel.show_panel()
