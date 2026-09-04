class_name SavePaths
extends RefCounted

# Where player progress lives, and it is NOT res://.
#
# res:// is baked into the .pck when the game is exported and is read-only from
# then on. Every progress file was written there, so an exported build would
# have run, played, and silently persisted nothing - the writes fail and there
# is no error path that would have told anybody. It only worked because the
# prototype has never been exported: in the editor res:// is a normal folder.
#
# THE LAYOUTS STAY WHERE THEY ARE. res://data also holds apron_layout,
# building_layout, cloud_layout, landmark_layout, paths, zone_regions and
# aircraft_rig, and those are not progress - they are CONTENT, authored with
# the in-game editors and shipped with the game. They are read at runtime and
# written only by a developer with the F1 tools open, which is exactly the case
# where res:// is writable. Moving them would mean a built game could not find
# its own airport.
#
# MIGRATION IS A FALLBACK, NOT A STEP. Reading prefers user:// and drops back
# to res://data when there is nothing there yet, so an existing playthrough is
# picked up on the next launch and written to user:// the first time it saves.
# Nothing is copied eagerly and nothing has to run once - a save that never
# writes simply keeps being read from where it already is.
const USER_DIR := "user://save"
const LEGACY_DIR := "res://data"


static func write_path(file_name: String) -> String:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	return "%s/%s" % [USER_DIR, file_name]


# The path to actually read, or "" when this file has never been written in
# either place - which is a first run, not an error.
static func read_path(file_name: String) -> String:
	var user := "%s/%s" % [USER_DIR, file_name]
	if FileAccess.file_exists(user):
		return user
	var legacy := "%s/%s" % [LEGACY_DIR, file_name]
	if FileAccess.file_exists(legacy):
		return legacy
	return ""


# Convenience for the common shape: read the text, or "" if there is none.
static func read_text(file_name: String) -> String:
	var path := read_path(file_name)
	if path == "":
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	if not f:
		return ""
	var text := f.get_as_text()
	f.close()
	return text


# Write, unless this is a bot run. Every progress writer went through its own
# copy of that guard and it leaked three times; there is one copy now, on the
# only path that writes progress.
static func write_text(file_name: String, text: String) -> bool:
	if OS.get_cmdline_user_args().has("--bot"):
		return false
	var f := FileAccess.open(write_path(file_name), FileAccess.WRITE)
	if not f:
		push_warning("SavePaths: could not write %s" % file_name)
		return false
	f.store_string(text)
	f.close()
	return true
