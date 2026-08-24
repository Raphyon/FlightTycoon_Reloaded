class_name CloseButton
extends RefCounted

# BUTTON SIZES, one convention for the whole game.
#
# The button art is @2x, so half its pixels is the size it was drawn to be shown
# at - the pill (button_orange2 / red1 / grey3, 136x62) is 68x31, and the WIDE
# one (button_orange4, 192x62) is 96x31. The wide art exists for a caption too
# long for the pill: "Depart all" is 62px against the pill's 68.
#
# On a board NOT drawn at the changelist scale, take a tenth of the board's
# width instead - see FriendInfoPanel. Boards run 0.72x to 1.20x of their own
# art, so a fixed pixel size reads shrunken on the big ones.
#
# And a button says what PRESSING it does. Prices, counts, levels and "can't
# afford" go on the board, the card or the price tag - never in the caption.


# The round X, top right. Built as a shared helper for the same reason
# BackButton is - so the panels using it can't drift apart.
#
# This is NOT a replacement for BackButton everywhere. The reference uses two
# different affordances for two different things: a full-screen panel (shop,
# hangar, routes) has the arrow bottom-right over a "Back" caption, and a
# dialog laid over the world (the route screen, the friend popup) has this X
# in its top-right corner. Which one a panel gets follows what it is.
const NORMAL := preload("res://assets/buttons/button_esc@2x.png")

# 1x NATIVE - button_esc is 72x72 @2x.
const SIZE := Vector2(36, 36)
# The X straddles the corner rather than sitting inside it, as in the
# reference - a third of the button hangs off the board.
const OVERHANG := 0.34


static func add_to(parent: Control, board_size: Vector2, on_pressed: Callable) -> TextureButton:
	var button := TextureButton.new()
	button.name = "CloseButton"
	# Before the texture, or the art's own size becomes the minimum and any
	# size set afterwards is silently clamped up to it.
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = NORMAL
	button.custom_minimum_size = SIZE
	button.size = SIZE
	button.position = Vector2(
		board_size.x - SIZE.x * (1.0 - OVERHANG),
		-SIZE.y * OVERHANG,
	)
	button.pressed.connect(on_pressed)
	parent.add_child(button)
	return button
