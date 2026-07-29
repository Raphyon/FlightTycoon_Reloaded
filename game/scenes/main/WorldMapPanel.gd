extends Control

# Destination picker, opened from the map tab under the top-left HUD panel.
# Two columns matching board_worldmap@2x.png: civil airports on the left,
# the military world on the right. Every button's label is baked into its
# own art, so there are no text nodes here.
#
# Only HomeLand actually exists as a scene right now - it's the world you're
# already standing in. The other three are real destinations in the original
# game but we have no scene for them, so they're shown dimmed rather than
# hidden: the player can see what's coming, and wiring one up later is a
# matter of flipping "implemented" and handling the key in _on_map_pressed.

signal map_chosen(map_key: String)

const UNAVAILABLE_MODULATE := Color(0.55, 0.58, 0.60, 1.0)

# Where the current-location badge sits relative to its map button's
# top-right corner - it overhangs the frame slightly, as in the reference.
const BADGE_OFFSET := Vector2(-46.0, -12.0)

const MAPS := [
	{"key": "homeland", "node": "HomeLandButton", "implemented": true},
	{"key": "dreamland", "node": "DreamLandButton", "implemented": false},
	{"key": "carriership", "node": "CarrierShipButton", "implemented": false},
	{"key": "skymaster", "node": "SkyMasterButton", "implemented": false},
]

# The world the player is currently in. Hardcoded until there's more than
# one scene to be in.
var current_map: String = "homeland"

@onready var _badge: TextureRect = $CurrentBadge
@onready var _esc_button: TextureButton = $EscButton


func _ready() -> void:
	_esc_button.pressed.connect(hide)
	for entry in MAPS:
		var button: TextureButton = get_node(entry["node"])
		button.pressed.connect(_on_map_pressed.bind(entry["key"]))
		if not entry["implemented"]:
			button.disabled = true
			button.modulate = UNAVAILABLE_MODULATE
	_refresh_badge()


func _refresh_badge() -> void:
	for entry in MAPS:
		if entry["key"] != current_map:
			continue
		var button: TextureButton = get_node(entry["node"])
		_badge.visible = true
		_badge.position = button.position + Vector2(button.size.x, 0.0) + BADGE_OFFSET
		return
	_badge.visible = false


func _on_map_pressed(map_key: String) -> void:
	if map_key == current_map:
		# Already here - nothing to travel to.
		return
	current_map = map_key
	_refresh_badge()
	map_chosen.emit(map_key)
