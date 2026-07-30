class_name FriendCard
extends RefCounted

# A friend's blue card.
#
# The friends LIST draws the whole thing - one of three card backs plus the
# contents. The info POPUP doesn't: board_friend_info already has a card (and
# the ring behind it) painted into the artwork, so there it only needs the
# contents laid over the card that's already there. populate() is the shared
# half, so where the cloud, portrait, name and level sit is defined once.
#
# Three backs exist, each a slightly different tilt. Which one a friend gets is
# derived from their key rather than drawn at random: reshuffling on every
# refresh would make the list flicker as you switch tabs.
const BACKS := [
	preload("res://assets/board/board_card5@2x.png"),
	preload("res://assets/board/board_card6@2x.png"),
	preload("res://assets/board/board_card7@2x.png"),
]
const CLOUD := preload("res://assets/bubbles/cloud_icon@2x.png")

const SIZE := Vector2(172, 204)
# All as fractions of the card, measured off the reference so the layout holds
# at whatever scale the card is drawn.
const CLOUD_Y := 0.15
const CLOUD_SIZE := Vector2(23, 16)
const CLOUD_GAP := 2.0
const AVATAR_TOP := 0.24
const AVATAR_HEIGHT := 0.40
const NAME_Y := 0.66
const LEVEL_Y := 0.79
const NAME_FONT := 17
const LEVEL_FONT := 19


static func back_for(map_key: String) -> Texture2D:
	return BACKS[absi(map_key.hash()) % BACKS.size()]


# The full card, back included - what the friends list shows.
static func build(map_key: String) -> Control:
	var root := Control.new()
	root.custom_minimum_size = SIZE
	root.size = SIZE
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var back := TextureRect.new()
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.texture = back_for(map_key)
	back.size = SIZE
	back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(back)

	populate(root, map_key, Rect2(Vector2.ZERO, SIZE))
	return root


# Contents only, laid into `rect`. Used by the popup, where the card art is
# already part of the background image.
static func populate(parent: Control, map_key: String, rect: Rect2) -> void:
	var info: Dictionary = Friends.info_for(map_key)
	var card_size := rect.size
	var factor := card_size.y / SIZE.y

	var clouds := _clouds(Fleet.distance_to(map_key), card_size, factor)
	clouds.position += rect.position
	parent.add_child(clouds)

	var avatar_path: String = info.get("avatar", "")
	if avatar_path != "":
		var avatar := TextureRect.new()
		avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		avatar.texture = load(avatar_path)
		avatar.position = rect.position + Vector2(0.0, card_size.y * AVATAR_TOP)
		avatar.size = Vector2(card_size.x, card_size.y * AVATAR_HEIGHT)
		avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(avatar)

	var name_label := _label(str(info.get("name", map_key)), card_size, NAME_Y,
		roundi(NAME_FONT * factor))
	name_label.position += rect.position
	parent.add_child(name_label)

	var level_label := _label("Lv.%d" % int(info.get("level", 1)), card_size, LEVEL_Y,
		roundi(LEVEL_FONT * factor))
	level_label.position += rect.position
	parent.add_child(level_label)


static func _label(text: String, card_size: Vector2, y: float, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.position = Vector2(0.0, card_size.y * y)
	l.size = Vector2(card_size.x, card_size.y * 0.13)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.06, 0.15, 0.28, 1))
	l.add_theme_constant_override("outline_size", maxi(2, roundi(4 * font_size / 17.0)))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# Distance, same as everywhere else it's shown - one cloud per unit.
static func _clouds(distance: int, card_size: Vector2, scale_factor: float) -> Control:
	var size := CLOUD_SIZE * scale_factor
	var gap := CLOUD_GAP * scale_factor
	var row := Control.new()
	row.position = Vector2(0.0, card_size.y * CLOUD_Y)
	row.size = Vector2(card_size.x, size.y)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var total := distance * size.x + maxf(0.0, distance - 1) * gap
	var x := (card_size.x - total) * 0.5
	for i in range(distance):
		var c := TextureRect.new()
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.texture = CLOUD
		c.position = Vector2(x + i * (size.x + gap), 0.0)
		c.size = size
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(c)
	return row
