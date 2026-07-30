class_name ShopCatalog
extends RefCounted

# Prices are arbitrary placeholders (we never captured the real game's
# actual /aircraft/aircraftMetaDataList values), roughly scaled by how big
# the aircraft looks so it's not nonsensical, but not real balance data.
#
# has_world_sprite: whether the model has body/shadow art to actually place
# on an apron. 328jet and p-51mustang were ingested from the dump; the jets
# and the Black Hawk are derived from their own shop icons (see
# tools/plane_derive.py and tools/blackhawk_derive.py); the A400M came in as
# a clean dump world sprite with its own 4-frame prop strip (WORLD_CLEAN in
# plane_derive.py).
#
# Every entry is true as of the A400M landing, so the flag currently gates
# nothing - it stays because it's the switch that keeps a model visible in
# the shop but unbuyable, and the next model we get a shop icon for before
# world art will need it again.
const ENTRIES := [
	{"key": "p51", "name": "P-51 Mustang", "icon": "p51_white.png", "price": 250, "has_world_sprite": true},
	{"key": "328jet", "name": "328 Jet", "icon": "328jet_blue.png", "price": 600, "has_world_sprite": true},
	{"key": "v22", "name": "V-22", "icon": "v22_green.png", "price": 1500, "has_world_sprite": true},
	{"key": "a318", "name": "Airbus A318", "icon": "a318_default.png", "price": 900, "has_world_sprite": true},
	{"key": "a319", "name": "Airbus A319", "icon": "a319_default.png", "price": 1100, "has_world_sprite": true},
	# TRIAL - world sprite is derived, not original art. See the "blackh"
	# entry in Fleet.WORLD_SPRITES for what that means and how to undo it.
	{"key": "blackh", "name": "Black Hawk", "icon": "blackh_green.png", "price": 1200, "has_world_sprite": true},
	{"key": "a300", "name": "Airbus A300", "icon": "a300_default.png", "price": 1600, "has_world_sprite": true},
	{"key": "747", "name": "Boeing 747", "icon": "747_default.png", "price": 2200, "has_world_sprite": true},
	{"key": "a400m", "name": "A400M", "icon": "a400m_white.png", "price": 2600, "has_world_sprite": true},
	{"key": "an-225", "name": "An-225", "icon": "an-225_default.png", "price": 3400, "has_world_sprite": true},
	{"key": "a380-300", "name": "Airbus A380", "icon": "a380-300_default.png", "price": 3800, "has_world_sprite": true},
	{"key": "airship", "name": "Airship", "icon": "airship_default.png", "price": 1800, "has_world_sprite": true},
	{"key": "ark", "name": "Ark", "icon": "ark_default.png", "price": 5000, "has_world_sprite": true},
	{"key": "ufo", "name": "UFO", "icon": "ufo_blue.png", "price": 9999, "has_world_sprite": true},
]
