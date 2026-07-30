class_name ZoneCatalog
extends RefCounted

# Display order + card art for the expansion shop. Zone1 is listed like
# everything else (it just always shows as already unlocked - see
# ZoneProgress.is_unlocked).
#
# These keys are also the area names in Maps and the unlock keys in
# ZoneProgress - one string identifies a zone everywhere. Dreamland1-3 belong
# to the Dream Land map and Carrier to the carrier, so buying one of those
# cards unlocks building on a different airport than the one you may be
# standing in.
const ENTRIES := [
	{"key": "Zone1", "name": "Zone 1", "card": "board_card10@2x.png", "implemented": true},
	{"key": "Zone2", "name": "Zone 2", "card": "board_card11@2x.png", "implemented": true},
	{"key": "DarkZone", "name": "Dark Zone", "card": "board_card12@2x.png", "implemented": true},
	{"key": "Forest", "name": "Forest", "card": "board_card13@2x.png", "implemented": true},
	{"key": "Desert", "name": "Desert", "card": "board_card14@2x.png", "implemented": true},
	{"key": "Beach", "name": "Beach", "card": "board_card15@2x.png", "implemented": true},
	{"key": "Snow", "name": "Snow", "card": "board_card16@2x.png", "implemented": true},
	{"key": "Dreamland1", "name": "Dreamland 1", "card": "board_card17@2x.png", "implemented": true},
	{"key": "Dreamland2", "name": "Dreamland 2", "card": "board_card18@2x.png", "implemented": true},
	{"key": "Dreamland3", "name": "Dreamland 3", "card": "board_card19@2x.png", "implemented": true},
	{"key": "Carrier", "name": "Carrier", "card": "board_card20@2x.png", "implemented": true},
]
