extends Control

# The gift box, on the shelf with the rest of the toolbar.
#
# IT USED TO FLOAT. It sat a quarter of the way down the LEFT EDGE, over the
# world - which is where the reference game puts it, but the reference game has
# nothing else there. Here it landed on the foliage beside the terminal, touching
# nothing and lined up with nothing, and read as a sprite that had come loose
# rather than as a control. Every other thing you can press in the HUD is either
# on the top bar or on the shelf; this was the only exception, and being the
# exception was the whole problem.
#
# It is a peer of the Shop, Hangar, Friends and Routes buttons - the comment
# below already said so about its SIZE - so it now sits where its peers sit,
# first on the shelf, immediately left of Shop.
#
# TWO PIECES OF ART, and which one is showing is the whole message: the plain box
# when there is nothing waiting, the badged one the moment there is. That is why
# there is no longer a drawn plate, a border or a row of pips under it - the art
# says it, and one slot on the shelf has room for exactly one statement.
#
# Both are cropped to a SHARED box (tools note: min/max of the two bounding
# boxes), because the badge on `new` overhangs to the left and cropping each to
# its own content would slide the gift box sideways the moment it appeared.
const GIFT_DEFAULT := preload("res://assets/buttons/daily_gift_default@2x.png")
const GIFT_NEW := preload("res://assets/buttons/daily_gift_new@2x.png")

# CAPPED AGAINST THE TOOLBAR. The Shop, Aircraft and Flights buttons are
# 109x102 each, and those are the biggest buttons in the game - this is a peer
# of theirs, not a bigger thing sitting off to one side, so it stays well under
# them at about two thirds their size.
#
# The art itself stays at 127x132 and is drawn down to this, which is sharper
# than authoring it at the drawn size.
const TAB_SIZE := Vector2(72, 75)

# The row's own height, from the Buttons container: 109x102 per button. The cell
# is the gift's width but the ROW's height, and the art sits at the bottom of it
# - the neighbouring buttons are plates whose art runs to their full 102, so a
# gift centred in the cell would hover above a shelf everything else rests on.
const ROW_HEIGHT := 102.0

var _icon: TextureRect
var _button: TextureButton


func _ready() -> void:
	# NO ANCHORS AND NO OFFSETS ANY MORE. The HBoxContainer on the shelf places
	# this now, off custom_minimum_size, and anchors set on a container's child
	# are overwritten every time it lays out - which is the trap the old edge
	# placement documented from the other side.
	Maps.map_changed.connect(func(_m = null) -> void: _refresh())
	custom_minimum_size = Vector2(TAB_SIZE.x, ROW_HEIGHT)
	var top := ROW_HEIGHT - TAB_SIZE.y

	_icon = TextureRect.new()
	_icon.position = Vector2(0.0, top)
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
	_button.position = Vector2(0.0, top)
	_button.size = TAB_SIZE
	_button.pressed.connect(_open)
	add_child(_button)

	Quests.quests_changed.connect(_refresh)
	Progression.level_changed.connect(func(_l: int) -> void: _refresh())
	_refresh()


# NOT FLOATING CHROME ANY MORE, so PanelManager no longer forces it down while a
# panel is open - it is covered by the full-screen panels exactly as the Shop and
# Hangar buttons beside it are, and left standing by the small ones exactly as
# they are. `visible` is still set here, and still is not cosmetic: it is the
# visiting rule below, which nothing else applies to this node.
#
# Not shown while visiting, like the rest of the shelf: the daily tasks are your
# airport's, and there is nothing to claim from somebody else's. Shop, Hangar and
# Friends drop out the same way in Toolbar._apply_map; Routes is the one that
# stays.
func _refresh(_a = null) -> void:
	if not is_instance_valid(_icon):
		return
	visible = not Maps.is_robot_map()
	_icon.texture = GIFT_NEW if Quests.has_anything_to_claim() else GIFT_DEFAULT


func _open() -> void:
	# FOUND FROM THE SCENE ROOT, not by counting "../". This node moved three
	# levels down when it joined the toolbar, and a relative path is precisely
	# what breaks silently when that happens: "../QuestsPanel" used to resolve
	# against UI and now resolves against the Buttons container, so it would
	# return null and the gift would be a button that does nothing.
	var panel: Node = owner.get_node_or_null("UI/QuestsPanel") if owner else null
	if panel and panel.has_method("open"):
		panel.open()
