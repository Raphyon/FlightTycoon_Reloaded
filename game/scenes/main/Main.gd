extends Node2D


func _ready() -> void:
	print("ft-proto booted")
	# Aprons and world aircraft (including the starting plane) are all
	# spawned by ApronEditor.gd, driven by Fleet's assignment data - see
	# AreaOrigins for the markers and data/apron_layout.json for the cells.
	Maps.map_changed.connect(_on_map_changed)
	_apply_map()
	$Camera2D.position = $ApronEditor.get_occupied_position()


# Travelling swaps the whole world: each airport is its own background at its
# own size, with its own aprons, clouds and traced paths. See Maps.
func _on_map_changed(_map_key: String) -> void:
	_apply_map()
	# Both editors key everything off the current map, so they have to rebuild
	# rather than keep showing the airport we just left. Deferred because a
	# rebuild frees the existing slot nodes.
	$ApronEditor.call_deferred("reload_for_map")
	$CloudEditor.call_deferred("reload_for_map")
	$PathEditor.call_deferred("reload_for_map")
	# Nothing is guaranteed to be occupied on a map you've never built on, so
	# fall back to the middle of the new world rather than leaving the camera
	# parked over wherever the last airport's aircraft was.
	call_deferred("_recentre_camera")


func _apply_map() -> void:
	$Background.texture = load(Maps.background_for())
	# The camera clamps to the world's edges, so its limits are per-map - left
	# at homeland's 3072x2304, a smaller airport would pan off into blank space.
	var size := Maps.size_for()
	var camera: Camera2D = $Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = size.x
	camera.limit_bottom = size.y


func _recentre_camera() -> void:
	var occupied: Vector2 = $ApronEditor.get_occupied_position()
	$Camera2D.position = occupied if occupied != Vector2.ZERO else Vector2(Maps.size_for()) * 0.5
