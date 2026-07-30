extends Control

# Destination picker, opened from the map tab under the top-left HUD panel.
# Two columns matching board_worldmap@2x.png: civil airports on the left,
# the military world on the right. Every button's label is baked into its
# own art, so there are no text nodes here.
#
# HomeLand, DreamLand and the CarrierShip are all real worlds now - see Maps,
# which owns the background, size and area list for each. SkyMaster has no
# background art in the dump, so it stays dimmed rather than hidden: the player
# can see what's coming, and wiring it up is a matter of adding it to Maps.
#
# Travel is instant. A transition/splash screen between airports would be the
# obvious polish here and is deliberately skipped for now.

signal map_chosen(map_key: String)

const UNAVAILABLE_MODULATE := Color(0.55, 0.58, 0.60, 1.0)

# Where the current-location badge sits relative to its map button's
# top-right corner - it overhangs the frame slightly, as in the reference.
const BADGE_OFFSET := Vector2(-46.0, -12.0)

# "implemented" is derived from Maps rather than repeated here, so adding a
# world in one place lights up its button automatically.
const MAPS := [
	{"key": "homeland", "node": "HomeLandButton"},
	{"key": "dreamland", "node": "DreamLandButton"},
	{"key": "carriership", "node": "CarrierShipButton"},
	{"key": "skymaster", "node": "SkyMasterButton"},
]

@onready var _badge: TextureRect = $CurrentBadge
@onready var _esc_button: TextureButton = $EscButton


func _ready() -> void:
	_esc_button.pressed.connect(hide)
	for entry in MAPS:
		var button: TextureButton = get_node(entry["node"])
		button.pressed.connect(_on_map_pressed.bind(entry["key"]))
		if not Maps.has_map(entry["key"]):
			button.disabled = true
			button.modulate = UNAVAILABLE_MODULATE
	Maps.map_changed.connect(func(_k: String) -> void: _refresh_badge())
	_refresh_badge()


func _refresh_badge() -> void:
	for entry in MAPS:
		if entry["key"] != Maps.current:
			continue
		var button: TextureButton = get_node(entry["node"])
		_badge.visible = true
		_badge.position = button.position + Vector2(button.size.x, 0.0) + BADGE_OFFSET
		return
	_badge.visible = false


func _on_map_pressed(map_key: String) -> void:
	# Maps.travel_to refuses a no-op (already here) or an unknown world, so the
	# badge and the signal only move when the world actually changed.
	if not Maps.travel_to(map_key):
		return
	_refresh_badge()
	map_chosen.emit(map_key)
	hide()
