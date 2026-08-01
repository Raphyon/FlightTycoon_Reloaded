class_name CloseButton
extends RefCounted

# The round X, top right. Built as a shared helper for the same reason
# BackButton is - so the panels using it can't drift apart.
#
# This is NOT a replacement for BackButton everywhere. The reference uses two
# different affordances for two different things: a full-screen panel (shop,
# hangar, routes) has the arrow bottom-right over a "Back" caption, and a
# dialog laid over the world (the route screen, the friend popup) has this X
# in its top-right corner. Which one a panel gets follows what it is.
const NORMAL := preload("res://assets/buttons/button_esc@2x.png")

const SIZE := Vector2(72, 72)
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
