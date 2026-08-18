class_name BuildingLayout
extends RefCounted

# Where the BUILDING PLOTS are - the empty construction sites, not the
# buildings. Placed by hand in game with the plot editor, for the same
# reason every other position in this project is: nothing measured exists for
# them, and working them out from the art has gone badly.
#
# The split matters. A plot is authored level data and lives here, in the repo.
# WHAT IS BUILT on a plot is the player's choice, made in the shop during play,
# and lives in BuildingProgress - exactly the way apron_layout holds where the
# pads are while apron_progress holds which you have bought.
#
# An earlier version of this file stored placed BUILDINGS, which had me
# authoring the player's airport for them.
#
#     {map_key: [{"id": 1, "x": 0.0, "y": 0.0, "site": "forest"}, ...]}
#
# "site" picks which construction-site art an EMPTY plot shows and defaults to
# "buildings". A plot on tarmac gets the fenced version; one on grass gets bare
# machinery, because a fenced concrete pad drawn on a forest floor reads as a
# mistake. Which plot is which is a placement decision, so it is set by hand in
# by hand in game rather than guessed from coordinates.
#
# Ids are stable and are what BuildingProgress keys against, so re-ordering or
# deleting a plot cannot silently move somebody's building to another site.
const SAVE_PATH := "res://data/building_layout.json"

# Everything tools/buildings_derive.py produces - what the shop offers for a
# plot, and what the editor cycles as a PREVIEW so you can check the biggest one
# still fits where you put the site.
#
# PRICE, RENT and PEOPLE are the LIVE game's, read off its own shop cards. Our
# names differ from its: its Coffee House is our roadside hotel and its Bar is
# our residential building.
#
#   price    cash, or coins where "coins" is set
#   rent     what one completed cycle pays
#   people   INHABITANTS the building adds - the second stat on every card, and
#            the brown counter in its HUD. Cumulative and permanent; unlike rent
#            it is not collected, you just have it once the building is up.
#   minutes  how long a cycle takes. THE ONE FIGURE THAT IS OURS - it is not
#            printed on the card, and nothing we have records it.
#   level    pilot level to unlock. Only the TV Tower (15) and the locked
#            "Level 16" card are confirmed; the rest are inferred from which
#            were already purchasable on a level-15 account.
#
# PAYBACK IS A CONSTANT in the original: every building costs almost exactly 15
# cycles of its own rent - 3000/200, 4000/260, 25000/1600, 32000/2100,
# 35000/2400 all land between 14.6 and 15.6. So price and rent are one decision
# there, not two, and the cycle length is what actually separates a cafe from a
# hotel. Ours rise gently with price so a bigger building still earns more per
# hour while asking you to come back less often.
const BUILDINGS := [
	{"key": "roadside_hotel", "name": "Coffee House", "price": 3000, "level": 1,
		"rent": 200, "people": 200, "minutes": 5},
	{"key": "cafe", "name": "Cafe", "price": 4000, "level": 1,
		"rent": 260, "people": 260, "minutes": 6},
	{"key": "residential_building", "name": "Bar", "price": 5000, "level": 2,
		"rent": 320, "people": 320, "minutes": 7},
	{"key": "business_center", "name": "Business Center", "price": 25000, "level": 10,
		"rent": 1600, "people": 2000, "minutes": 12},
	{"key": "grand_hotel", "name": "Grand Hotel", "price": 32000, "level": 12,
		"rent": 2100, "people": 3000, "minutes": 14},
	{"key": "garden_hotel", "name": "Garden Hotel", "price": 35000, "level": 13,
		"rent": 2400, "people": 3500, "minutes": 15},
	{"key": "tv_tower", "name": "TV Tower", "price": 28000, "level": 15,
		"rent": 1900, "people": 2500, "minutes": 13},
	# The locked card on the level-15 page: 40,000 at level 16. Which building
	# it is wasn't legible, so the Office takes the slot - it is the one model
	# we have with no live figures of its own.
	{"key": "office_building", "name": "Office", "price": 40000, "level": 16,
		"rent": 2700, "people": 4000, "minutes": 16},
	# The one coin building, and the only one whose people figure outruns its
	# rent by that much - a landmark rather than a business.
	{"key": "eifel_tower", "name": "Eiffel Tower", "price": 30, "currency": "coins", "level": 1,
		"rent": 5000, "people": 8000, "minutes": 20},
]


static func name_of(key: String) -> String:
	return str(entry(key).get("name", key))


static func price_of(key: String) -> int:
	return int(entry(key).get("price", 0))


static func currency_of(key: String) -> String:
	return str(entry(key).get("currency", "cash"))


static func level_of(key: String) -> int:
	return int(entry(key).get("level", 1))


static func people_of(key: String) -> int:
	return int(entry(key).get("people", 0))


static func rent_of(key: String) -> int:
	return int(entry(key).get("rent", 0))


static func cycle_seconds(key: String) -> float:
	return float(entry(key).get("minutes", 0)) * 60.0


# The empty-plot art, by site type. Keys are what a plot's "site" field holds.
const SITE_TEXTURES := {
	"buildings": "res://assets/buildings/construction_site_2x.png",
	"forest": "res://assets/buildings/construction_site_forest_2x.png",
}


static func site_types() -> Array:
	return SITE_TEXTURES.keys()


static func site_texture_path(site: String) -> String:
	return str(SITE_TEXTURES.get(site, SITE_TEXTURES["buildings"]))


static func texture_path(key: String) -> String:
	return "res://assets/buildings/%s_2x.png" % key


static func entry(key: String) -> Dictionary:
	for b in BUILDINGS:
		if b["key"] == key:
			return b
	return {}


static func display_name(key: String) -> String:
	return str(entry(key).get("name", key))


static func load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func save_all(all_data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(all_data, "\t"))
	f.close()


# One airport's plots - the current one unless told otherwise.
static func load_data(map_key: String = "") -> Array:
	var key := map_key if map_key != "" else Maps.current
	var got: Variant = load_all().get(key, [])
	return got if got is Array else []


static func save_data(data: Array, map_key: String = "") -> void:
	var key := map_key if map_key != "" else Maps.current
	var all_data := load_all()
	all_data[key] = data
	save_all(all_data)


# Lowest id not already taken, so deleting a plot frees its number instead of
# letting ids climb forever.
static func next_id(data: Array) -> int:
	var used := {}
	for p in data:
		used[int(p.get("id", 0))] = true
	var i := 1
	while used.has(i):
		i += 1
	return i


static func plot_by_id(plot_id: int, map_key: String = "") -> Dictionary:
	for p in load_data(map_key):
		if int(p.get("id", 0)) == plot_id:
			return p
	return {}
