extends Node

# Central switchboard for the development overlays and placement tools.
#
# These were all on permanently while the airport was being laid out - apron
# id numbers, the coloured free/occupied tints, the reference grid. They read
# as debug scaffolding rather than game, so they now default OFF and are
# turned on from DebugMenu (F1).
#
# Nothing here is persisted: a fresh run always starts clean, so a forgotten
# toggle can't quietly ship. Same reasoning as the DEBUG_STARTING_MONEY
# switch in Economy being a separate, obvious constant.

signal flags_changed

var show_apron_ids := false      # the number drawn on each built apron
var show_apron_tints := false    # green/orange free-vs-occupied diamonds
var show_apron_costs := false    # the "$1000" on unbuilt aprons
var show_grid := false           # the isometric reference lattice


func set_flag(flag: StringName, value: bool) -> void:
	if not has_flag(flag):
		push_warning("DebugState: unknown flag %s" % flag)
		return
	set(flag, value)
	flags_changed.emit()


func toggle_flag(flag: StringName) -> void:
	set_flag(flag, not get(flag))


func has_flag(flag: StringName) -> bool:
	for p in get_property_list():
		if p["name"] == flag and p["type"] == TYPE_BOOL:
			return true
	return false
