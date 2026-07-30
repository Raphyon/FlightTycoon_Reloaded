extends Node

# Who's on the friends list. A friend is a visitable airport (see Maps), so
# there's no separate roster - this only tracks the part Maps can't: which
# friends you've removed.
#
# Removal persists; the robot can't be removed at all, since your dispatched
# aircraft land at its airport and unfriending it would strand them.
signal friends_changed

const SAVE_PATH := "res://data/friends.json"

var removed: Dictionary = {}  # map_key -> true


func _ready() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		removed = parsed


func _save() -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(removed, "\t"))
	f.close()


func info_for(map_key: String) -> Dictionary:
	return Maps.entry(map_key).get("visiting", {})


func can_remove(map_key: String) -> bool:
	return info_for(map_key).get("removable", true)


func list() -> Array:
	var out: Array = []
	for key in Maps.visitable_maps():
		if not removed.has(key):
			out.append(key)
	return out


func remove(map_key: String) -> bool:
	if not can_remove(map_key) or removed.has(map_key):
		return false
	removed[map_key] = true
	_save()
	friends_changed.emit()
	return true
