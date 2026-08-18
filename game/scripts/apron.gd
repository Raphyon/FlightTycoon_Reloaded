class_name Apron
extends RefCounted

var id: int
var grid_pos: Vector2i
var screen_pos: Vector2
var area_name: String
# Whether a Fleet aircraft is parked here - set by ApronLayer after
# building, from Fleet.get_aircraft_at_apron(), not passed in at
# construction. There's no independent "occupied" state anymore; it's
# always a direct reflection of Fleet's assignment data.
var occupied: bool = false

# Zone1's first 5 aprons come free; see ApronLayout.build_area_aprons.
var free_by_default: bool = false

# Whether this apron has been built yet - read live from ApronProgress
# rather than cached. It used to be a plain field written once when the
# aprons were rebuilt, which went stale the moment something was built:
# ApronLayer only rebuilds on Fleet.fleet_changed, so after a purchase the
# apron still reported false and kept showing its construction site.
# ApronInfoPanel had already grown an "or ApronProgress.is_built(id)" patch
# around the same problem; computing it here fixes every reader at once.
var built: bool:
	get:
		return free_by_default or ApronProgress.is_built(id)


func _init(p_id: int, p_grid_pos: Vector2i, p_screen_pos: Vector2) -> void:
	id = p_id
	grid_pos = p_grid_pos
	screen_pos = p_screen_pos
