class_name CloudLayout
extends RefCounted

# {area_name: [x,y]} - one placed point per lockable zone, set by hand with
# CloudEditor the same way apron points are (see ApronLayout) - no
# positional data exists anywhere for these cloud crops, so they're placed
# by eye, not measured.
const SAVE_PATH := "res://data/cloud_layout.json"

# Zone1 has no cloud (always unlocked, start zone).
const LOCKABLE_AREAS: Array[String] = [
	"Zone2", "DarkZone", "Forest", "Desert", "Beach", "Snow"
]

const CLOUD_TEXTURES := {
	"Zone2": "res://assets/cloud/airport001_area002_cloud.png",
	"DarkZone": "res://assets/cloud/airport001_area003_cloud.png",
	"Forest": "res://assets/cloud/airport001_area004_cloud.png",
	"Desert": "res://assets/cloud/airport001_area005_cloud.png",
	"Beach": "res://assets/cloud/airport001_area006_cloud.png",
	"Snow": "res://assets/cloud/airport001_area007_cloud.png",
}


static func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}


static func save_data(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
