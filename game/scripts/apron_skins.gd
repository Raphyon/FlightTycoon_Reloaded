extends Node

signal skin_changed
signal owned_changed

# Every skin costs the same and gives the same flat bonus - the choice is
# purely cosmetic. Placeholder economy numbers per the user's exact spec.
const SKIN_COST := 10
const BONUS_PERCENT := 15

# Each skin unlocks at its own level, which is the point of them: between the
# starting aircraft at level 1 and the P-51 at level 10 there was nothing at
# all to earn, and that is the stretch that has to hold a new player. Eight
# skins arriving one at a time fill it, then keep going at a widening spacing.
#
# The art is identical in value - the bonus and the price are the same for all
# eight (the user's spec) - so what a skin buys you is the choice, and what the
# level buys you is a new choice arriving.
const SKINS := [
	{"key": "apronpaint01", "name": "Target", "level": 2, "texture": "res://assets/aprons/apronpaint01@2x.png"},
	{"key": "apronpaint02", "name": "Ocean Gems", "level": 3, "texture": "res://assets/aprons/apronpaint02@2x.png"},
	{"key": "apronpaint03", "name": "Celebration Cake", "level": 5, "texture": "res://assets/aprons/apronpaint03@2x.png"},
	{"key": "apronpaint04", "name": "Gold Rush", "level": 7, "texture": "res://assets/aprons/apronpaint04@2x.png"},
	{"key": "apronpaint05", "name": "Skull & Bones", "level": 9, "texture": "res://assets/aprons/apronpaint05@2x.png"},
	{"key": "apronpaint06", "name": "Sweetheart", "level": 12, "texture": "res://assets/aprons/apronpaint06@2x.png"},
	{"key": "apronpaint07", "name": "Starlight", "level": 16, "texture": "res://assets/aprons/apronpaint07@2x.png"},
	{"key": "apronpaint08", "name": "Pyramid", "level": 20, "texture": "res://assets/aprons/apronpaint08@2x.png"},
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


func level_for(skin_key: String) -> int:
	for entry in SKINS:
		if entry["key"] == skin_key:
			return int(entry.get("level", 1))
	return 1


func is_unlocked(skin_key: String) -> bool:
	return Progression.level >= level_for(skin_key)


# A fresh game has no pads, so it cannot have painted ones. Neither of these
# files was cleared by SaveGame.reset_to_defaults - apron_skins.json is not even
# in PROGRESS_FILES - so a reset left the skins applied to aprons that no longer
# existed, waiting for their ids to come round again.
func reset() -> void:
	_applied.clear()
	owned.clear()
	_save(SAVE_PATH, _applied)
	_save(OWNED_SAVE_PATH, owned)
	skin_changed.emit()
	owned_changed.emit()


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
	# Gated here rather than only on the button, same as aircraft in Fleet.buy.
	if not is_unlocked(skin_key):
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
	# A bot run writes nothing to disk - see SaveGame.is_bot_run().
	if SaveGame.is_bot_run():
		return
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
