extends Control

# COLLECTING RENT WAS A LAP OF THE BOARD. Every finished building is its own
# tap, on a plot you have to find first, and with 42 of them the collecting
# outgrew the deciding - which is the shape Depart All was added to fix on the
# fleet side. BuildingProgress.collect_all() has existed the whole time and
# only the bot ever called it.
#
# It shows ONLY when there is something to collect, and says how many, so it is
# never a button you press to be told no. Same rule as BoostButton, and it is
# registered in PanelManager.CHROME so it gets out of the way of an open panel.
const ICON := preload("res://assets/hud/icon_medium_money1@2x.png")
const SIZE := Vector2(52, 52)
const BADGE_FONT := 12

var _button: TextureButton
var _badge: Label


func _ready() -> void:
	_button = TextureButton.new()
	_button.focus_mode = Control.FOCUS_NONE
	_button.ignore_texture_size = true
	_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_button.texture_normal = ICON
	_button.custom_minimum_size = SIZE
	_button.size = SIZE
	_button.pressed.connect(_collect)
	add_child(_button)

	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", BADGE_FONT)
	_badge.add_theme_color_override("font_color", Color.WHITE)
	_badge.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	_badge.add_theme_constant_override("outline_size", 4)
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.size = Vector2(SIZE.x, 16.0)
	_badge.position = Vector2(0.0, SIZE.y - 14.0)
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badge)

	# Rent comes ready on a timer rather than on an event, so a signal alone
	# would leave the button a minute stale. built_changed catches building and
	# demolishing; the tick catches ripening.
	BuildingProgress.built_changed.connect(_refresh)
	Maps.map_changed.connect(_refresh)
	var timer := Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_refresh)
	add_child(timer)
	timer.start()
	_refresh()


func _collect() -> void:
	BuildingProgress.collect_all()
	_refresh()


# Named _refresh to match BoostButton and QuestsButton: PanelManager calls it by
# name to let chrome decide for itself once a panel closes.
func _refresh(_a = null) -> void:
	var ready_count: int = BuildingProgress.ready_plots().size()
	visible = ready_count > 0
	_badge.text = str(ready_count) if ready_count > 0 else ""
