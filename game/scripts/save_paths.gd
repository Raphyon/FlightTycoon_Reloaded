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

# WHAT THE SAVE FOLDER WAS CALLED BEFORE THE PROJECT WAS. Godot derives
# user:// from config/name, so renaming the project from "ft-proto" to
# "Flight Tycoon" pointed the game at an empty directory - every save, mine and
# every tester's, still on disk with nothing reading it. The README argued for
# years that the internal name was not worth a migration because it was seen
# nowhere but that table; shipping a macOS build made that false, because the
# name is the .app, the dock label and the title bar.
#
# So the rename happens and this is the cost of it: one more place to look.
# The old directory is a SIBLING of the new one - both sit under app_userdata -
# so it can be found from the current path rather than rebuilt per platform.
const PRE_RENAME_DIR_NAME := "ft-proto"


# The pre-rename save folder, or "" where the platform does not lay user data
# out that way. Never written to - see write_path. A save found here is read
# once and lands in the new folder the next time anything saves, which is the
# same shape as the res://data fallback below it and needs no migration step
# that has to run exactly once.
static func pre_rename_dir() -> String:
	var here := OS.get_user_data_dir()
	if here == "":
		return ""
	return "%s/%s/save" % [here.get_base_dir(), PRE_RENAME_DIR_NAME]


static func write_path(file_name: String) -> String:
	DirAccess.make_dir_recursive_absolute(USER_DIR)
	return "%s/%s" % [USER_DIR, file_name]


# The path to actually read, or "" when this file has never been written in
# either place - which is a first run, not an error.
static func read_path(file_name: String) -> String:
	var user := "%s/%s" % [USER_DIR, file_name]
	if FileAccess.file_exists(user):
		return user
	var renamed := pre_rename_dir()
	if renamed != "":
		var before := "%s/%s" % [renamed, file_name]
		if FileAccess.file_exists(before):
			return before
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
