extends Node2D

# Ambient background traffic. Every road traced with PathEditor (press T,
# then 3 for roads) periodically spawns a random vehicle matching that
# road's category - airport service vehicles never appear on commercial
# roads and vice versa. Each spawn travels the road's traced path start to
# end at a steady speed, then despawns off the far end. A road is one
# direction only - trace a second, separate road for opposing traffic (see
# PathEditor).
#
# Each vehicle has two art variants, both extracted from the source sheet:
# a "front" (facing down-left) and a "back" (facing up-right, the same
# vehicle rotated 180 degrees) - a standard isometric 4-direction rig once
# combined with a horizontal flip. Which one shows, and whether it's
# flipped, is picked every frame from the vehicle's actual current heading
# along the path, not just the road's overall start/end - a bent road can
# face a different way partway through.
const VEHICLE_SPEED := 78.0  # px/sec, steady driving speed (no accel/liftoff - that's just for departing planes)
const MIN_GAP_SECONDS := 1.8  # per road - keeps consecutive spawns from stacking on each other
const MAX_GAP_SECONDS := 4.5  # wider spread than the gap itself is short, so timing still feels random rather than metronomic
const VEHICLE_DIR := "res://assets/vehicles/"

const VEHICLES_BY_CATEGORY := {
	"commercial": ["suv_orange", "sedan_lightblue", "red_sedan", "green_sedan", "bus", "purple_bus"],
	"airport": ["tow_tractor", "fuel_tanker", "service_truck", "forklift", "red_truck"],
}

var _roads: Dictionary = {}  # road_name -> {category, points: Array[Vector2]}
var _next_spawn: Dictionary = {}  # road_name -> seconds remaining


func _ready() -> void:
	_reload_roads()
	get_node("../PathEditor").roads_changed.connect(_reload_roads)
	# Roads are traced per airport, so travelling has to drop the old ones and
	# clear any vehicle still driving along a road that no longer exists here.
	Maps.map_changed.connect(_on_map_changed)


func _on_map_changed(_map_key: String) -> void:
	for vehicle in get_children():
		vehicle.queue_free()
	_next_spawn.clear()
	_reload_roads()


func _reload_roads() -> void:
	var data := PathLayout.load_effective()
	# .get(): an airport with no traced roads has no "roads" key at all.
	var roads: Dictionary = data.get("roads", {})
	_roads.clear()
	for road_name in roads.keys():
		var road: Dictionary = roads[road_name]
		_roads[road_name] = {
			"category": road["category"],
			"points": PathLayout.points_to_vectors(road["points"]),
		}
		if not _next_spawn.has(road_name):
			_next_spawn[road_name] = randf_range(0.0, MAX_GAP_SECONDS)
	for road_name in _next_spawn.keys().duplicate():
		if not _roads.has(road_name):
			_next_spawn.erase(road_name)


func _process(delta: float) -> void:
	for road_name in _roads.keys():
		_next_spawn[road_name] -= delta
		if _next_spawn[road_name] <= 0.0:
			_next_spawn[road_name] = randf_range(MIN_GAP_SECONDS, MAX_GAP_SECONDS)
			_spawn(_roads[road_name])


func _spawn(road: Dictionary) -> void:
	var points: Array[Vector2] = []
	points.assign(road["points"])
	if points.size() < 2:
		return
	var keys: Array = VEHICLES_BY_CATEGORY.get(road["category"], [])
	if keys.is_empty():
		return
	var key: String = keys[randi() % keys.size()]

	var vehicle := Sprite2D.new()
	vehicle.position = points[0]
	add_child(vehicle)
	_update_facing(vehicle, key, PathLayout.direction_along_path(points, 0.0))

	var total_distance := 0.0
	for i in range(points.size() - 1):
		total_distance += points[i].distance_to(points[i + 1])
	var duration := total_distance / VEHICLE_SPEED

	# Bound to the vehicle, not to self: Godot kills a node's own tweens when
	# the node is freed, so a vehicle removed mid-drive takes its tween with
	# it. Created on self, the tween outlived the sprite and kept assigning to
	# a freed object - which is what travelling between airports triggered,
	# since that clears traffic that's still part-way along a road.
	var tween := vehicle.create_tween()
	tween.tween_method(
		func(u: float) -> void: _on_vehicle_progress(vehicle, key, points, u),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_LINEAR)
	tween.tween_callback(vehicle.queue_free)


func _on_vehicle_progress(vehicle: Sprite2D, key: String, points: Array[Vector2], u: float) -> void:
	# queue_free is deferred, so a tween can still get one more tick in after
	# the vehicle is marked for removal.
	if not is_instance_valid(vehicle):
		return
	vehicle.position = PathLayout.position_along_path(points, u)
	_update_facing(vehicle, key, PathLayout.direction_along_path(points, u))


# Front vs back is picked by vertical heading (moving down the screen =
# toward camera = front, up = away = back); left vs right is a horizontal
# flip on top of that - together they cover all 4 iso-diagonal directions
# from just the 2 drawn variants.
func _update_facing(vehicle: Sprite2D, key: String, direction: Vector2) -> void:
	var facing_back := direction.y < 0.0
	var path := "%s%s%s@2x.png" % [VEHICLE_DIR, key, "_back" if facing_back else ""]
	if vehicle.get_meta("texture_path", "") != path:
		vehicle.texture = load(path)
		vehicle.set_meta("texture_path", path)
	# Front unflipped is drawn heading SW; flipping it mirrors to SE. Back is
	# that same body rotated 180 degrees (not mirrored) to NE, so ITS flip
	# runs the opposite way - unflipped back is NE, flipped back is NW.
	# Using front's dx>=0 rule for both would show back-unflipped (NE) for
	# NW-heading traffic instead of back-flipped.
	var flip: bool = (direction.x >= 0.0) != facing_back
	vehicle.scale.x = -1.0 if flip else 1.0
