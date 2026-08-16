extends Control

# The left-edge tab that opens the daily tasks, where the reference game puts
# its DAILY REWARD gift box.
#
# DRAWN IN CODE, ON PURPOSE. There is no gift-box art in the dump - nothing for
# DAILY REWARD, PURCHASE BONUS or EVENT - so this is a placeholder built from
# the coin icon we do have. Swapping in real art is replacing the TextureRect
# below and deleting _draw; the behaviour does not change.
#
# IT REPORTS PROGRESS AT A GLANCE. Three pips, one per task, filled as they
# complete - so the tab answers "is there anything to do today" without being
# opened, which is the entire job of a thing sitting on the edge of the screen.
# When the set is claimable it pulses, because at that point there IS something
# to collect and a static icon would not say so.

# The gift box on the left edge, where the reference game puts its DAILY REWARD.
#
# TWO PIECES OF ART, and which one is showing is the whole message: the plain box
# when there is nothing waiting, the badged one the moment there is. That is why
# there is no longer a drawn plate, a border or a row of pips under it - the art
# says it, and a tab on the edge of the screen has room for exactly one
# statement.
#
# Both are cropped to a SHARED box (tools note: min/max of the two bounding
# boxes), because the badge on `new` overhangs to the left and cropping each to
# its own content would slide the gift box sideways the moment it appeared.
const GIFT_DEFAULT := preload("res://assets/buttons/daily_gift_default@2x.png")
const GIFT_NEW := preload("res://assets/buttons/daily_gift_new@2x.png")

# CAPPED AGAINST THE TOOLBAR. The Shop, Aircraft and Flights buttons are
# 109x102 each, and those are the biggest buttons in the game - this is a peer
# of theirs, not a bigger thing sitting off to one side, so it stays under them.
#
# The art itself stays at 127x132 and is drawn down to this, which is sharper
# than authoring it at the drawn size.
const TAB_SIZE := Vector2(88, 91)
const EDGE_MARGIN := 12.0
# How far down the left edge, as a fraction of screen height. A QUARTER, not
# half: that is where the reference game puts its NEWS icon, with the daily
# reward gift box directly beneath it. Proportional rather than a pixel offset
# so it holds its place on a screen of any height.
const EDGE_HEIGHT_FRACTION := 0.25

var _icon: TextureRect
var _button: TextureButton


func _ready() -> void:
	# Left edge, a quarter of the way down - where the reference game's NEWS
	# icon sits. Clear of the player card in the top corner and of the toolbar
	# along the bottom.
	#
	# ALL FOUR ANCHORS AND ALL FOUR OFFSETS, explicitly. set_anchors_preset
	# followed by assigning `position` left the right/bottom offsets stale and
	# put the tab at y=-46, off the top of the screen - the same trap the debug
	# menu hit. There is no shorthand here that is worth the ambiguity.
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = EDGE_HEIGHT_FRACTION
	anchor_bottom = EDGE_HEIGHT_FRACTION
	offset_left = EDGE_MARGIN
	offset_right = EDGE_MARGIN + TAB_SIZE.x
	offset_top = -TAB_SIZE.y * 0.5
	offset_bottom = TAB_SIZE.y * 0.5

	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Minimum first, THEN the size - a TextureRect's own art is its minimum size
	# until expand_mode says otherwise, and a size assigned before that line is
	# silently clamped back up to the full 127x132.
	_icon.custom_minimum_size = Vector2.ZERO
	_icon.size = TAB_SIZE
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)

	_button = TextureButton.new()
	_button.ignore_texture_size = true
	_button.stretch_mode = TextureButton.STRETCH_SCALE
	_button.size = TAB_SIZE
	_button.pressed.connect(_open)
	add_child(_button)

	Quests.quests_changed.connect(_refresh)
	Progression.level_changed.connect(func(_l: int) -> void: _refresh())
	_refresh()


func _refresh(_a = null) -> void:
	if not is_instance_valid(_icon):
		return
	_icon.texture = GIFT_NEW if Quests.has_anything_to_claim() else GIFT_DEFAULT


func _open() -> void:
	var panel := get_node_or_null("../QuestsPanel")
	if panel and panel.has_method("open"):
		panel.open()
