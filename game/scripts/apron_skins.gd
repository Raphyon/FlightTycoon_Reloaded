extends Node

signal skin_changed
signal owned_changed

# Every skin costs the same and gives the same flat bonus - the choice is
# purely cosmetic. Placeholder economy numbers per the user's exact spec.
const SKIN_COST := 10
const BONUS_PERCENT := 15

const SKINS := [
	{"key": "apronpaint01", "name": "Target", "texture": "res://assets/aprons/apronpaint01@2x.png"},
	{"key": "apronpaint02", "name": "Ocean Gems", "texture": "res://assets/aprons/apronpaint02@2x.png"},
	{"key": "apronpaint03", "name": "Celebration Cake", "texture": "res://assets/aprons/apronpaint03@2x.png"},
	{"key": "apronpaint04", "name": "Gold Rush", "texture": "res://assets/aprons/apronpaint04@2x.png"},
	{"key": "apronpaint05", "name": "Skull & Bones", "texture": "res://assets/aprons/apronpaint05@2x.png"},
	{"key": "apronpaint06", "name": "Sweetheart", "texture": "res://assets/aprons/apronpaint06@2x.png"},
	{"key": "apronpaint07", "name": "Starlight", "texture": "res://assets/aprons/apronpaint07@2x.png"},
	{"key": "apronpaint08", "name": "Pyramid", "texture": "res://assets/aprons/apronpaint08@2x.png"},
]

const SAVE_PATH := "res://data/apron_skins.json"
const OWNED_SAVE_PATH := "res://data/apron_skins_owned.json"

var _applied: Dictionary = {}  # str(apron_id) -> skin_key, persisted
# str(apron_id) -> {skin_key: true}. Skins are bought FOR AN APRON, not for the
# airport: one purchase paints one pad. It used to be a flat skin_key -> true,
# which meant 10 coins unlocked that skin on all ~110 aprons - and since a
# skinned apron also pays BONUS_PERCENT more, that was a permanent +15% on the
# whole airport for the price of one pad.
#
# Owning is still per-skin within a pad, so once you've bought two for the same
# apron you can switch between them for nothing.
var owned: Dictionary = {}


func _ready() -> void:
	_applied = _load(SAVE_PATH)
	owned = _migrate(_load(OWNED_SAVE_PATH))


# The old save was a flat set of skin keys with no apron attached. There's no
# honest way to spread that across pads, so it's granted to whichever aprons
# are actually wearing those skins and dropped everywhere else - the player
# keeps what they can see, and nothing more.
func _migrate(data: Dictionary) -> Dictionary:
	var is_legacy := false
	for key in data:
		if not str(key).is_valid_int():
			is_legacy = true
			break
	if not is_legacy:
		return data
	var out := {}
	for apron_key in _applied:
		var skin: String = str(_applied[apron_key])
		if data.has(skin):
			out[str(apron_key)] = {skin: true}
	_save(OWNED_SAVE_PATH, out)
	return out


func get_skin_key(apron_id: int) -> String:
	return _applied.get(str(apron_id), "")


func get_skin_entry(apron_id: int) -> Dictionary:
	var key := get_skin_key(apron_id)
	for entry in SKINS:
		if entry["key"] == key:
			return entry
	return {}


func is_owned(apron_id: int, skin_key: String) -> bool:
	var for_apron: Dictionary = owned.get(str(apron_id), {})
	return for_apron.has(skin_key)


# How many pads are wearing a skin - the bonus is per apron, so this is what
# the total income boost is actually worth.
func skinned_apron_count() -> int:
	return _applied.size()


func bonus_percent_for(apron_id: int) -> int:
	return BONUS_PERCENT if not get_skin_key(apron_id).is_empty() else 0


func buy_skin(apron_id: int, skin_key: String) -> bool:
	if is_owned(apron_id, skin_key):
		return false
	if not Coins.spend(SKIN_COST):
		return false
	owned = _migrate(_load(OWNED_SAVE_PATH))
	var for_apron: Dictionary = owned.get(str(apron_id), {})
	for_apron[skin_key] = true
	owned[str(apron_id)] = for_apron
	_save(OWNED_SAVE_PATH, owned)
	owned_changed.emit()
	return true


func set_skin(apron_id: int, skin_key: String) -> void:
	if not is_owned(apron_id, skin_key):
		return
	_applied = _load(SAVE_PATH)
	_applied[str(apron_id)] = skin_key
	_save(SAVE_PATH, _applied)
	skin_changed.emit()


func _load(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


func _save(path: String, data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
