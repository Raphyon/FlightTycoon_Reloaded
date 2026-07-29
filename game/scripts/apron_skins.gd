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
var owned: Dictionary = {}  # skin_key -> true, persisted


func _ready() -> void:
	_applied = _load(SAVE_PATH)
	owned = _load(OWNED_SAVE_PATH)


func get_skin_key(apron_id: int) -> String:
	return _applied.get(str(apron_id), "")


func get_skin_entry(apron_id: int) -> Dictionary:
	var key := get_skin_key(apron_id)
	for entry in SKINS:
		if entry["key"] == key:
			return entry
	return {}


func is_owned(skin_key: String) -> bool:
	return owned.has(skin_key)


func bonus_percent_for(apron_id: int) -> int:
	return BONUS_PERCENT if not get_skin_key(apron_id).is_empty() else 0


func buy_skin(skin_key: String) -> bool:
	if is_owned(skin_key):
		return false
	if not Coins.spend(SKIN_COST):
		return false
	owned = _load(OWNED_SAVE_PATH)
	owned[skin_key] = true
	_save(OWNED_SAVE_PATH, owned)
	owned_changed.emit()
	return true


func set_skin(apron_id: int, skin_key: String) -> void:
	if not is_owned(skin_key):
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
