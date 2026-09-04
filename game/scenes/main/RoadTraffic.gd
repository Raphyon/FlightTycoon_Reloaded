extends Node2D

# Ambient background traffic. Every road traced with PathLayer (press T,
# then 3 for roads) periodically spawns a random vehicle matching that
# road's category - airport service vehicles never appear on commercial
# roads and vice versa. Each spawn travels the road's traced path start to
# end at a steady speed, then despawns off the far end. A road is one
# direction only - trace a second, separate road for opposing traffic (see
# PathLayer).
#
# Each vehicle has two art variants, both extracted from the source sheet:
# a "front" (facing down-left) and a "back" (facing up-right, the same
# vehicle rotated 180 degrees) - a standard isometric 4-direction rig once
# combined with a horizontal flip. Which one shows, and whether it's
# flipped, is picked every frame from the vehicle's actual current heading
# along the path, not just the road's overall start/end - a bent road can
# face a different way partway through.
const VEHICLE_SPEED := 78.0  # px/sec, steady driving speed (no accel/liftoff - that's just for departing planes)
# HEADWAYS ARE EXPONENTIAL, NOT UNIFORM, because real arrivals are Poisson and
# a uniform draw is the one shape that cannot look like traffic. Picking evenly
# from 1.8..4.5 meant no gap was ever under 1.8s and none was ever over 4.5s:
# every road emitted a steady stream at a mean of 3.15s, which reads as a
# conveyor of cars rather than as traffic. Widening that window would not have
# helped - the distribution was the problem, not its bounds.
#
# A shifted exponential clusters on its own: vehicles arrive in twos and threes
# and then the road is empty for a while, which is what a road looks like.
# Against the old uniform draw, a quarter of gaps now land in the 10-20s band
# and 11% run past 20s, where before nothing ever exceeded 4.5s.
#
# MIN is the floor a shift buys: it is the physical headway, close enough that
# two cars never overlap, and everything above it is drawn.
const MIN_GAP_SECONDS := 1.8
# The average, and the volume dial - the only number to touch to make an
# airport busier or quieter. 10.0 is about 371 vehicles an hour on a road
# against the 1,143 the uniform draw was producing. It also sets the tail,
# since an exponential's mean and its spread are the same number: at 10.0 the
# median gap is 7.5s, 37% of gaps clear 10s and 11% clear 20s, so a road runs
# visibly empty between clumps rather than merely thinning out.
const MEAN_GAP_SECONDS := 10.0
# A lull has to end. Uncapped, the exponential's tail occasionally leaves a
# road dead for a minute, which stops reading as quiet and starts reading as
# broken. At 30 that is clipped in about 5% of draws.
const MAX_GAP_SECONDS := 30.0
const VEHICLE_DIR := "res://assets/vehicles/"

const VEHICLES_BY_CATEGORY := {
	"commercial": ["suv_orange", "sedan_lightblue", "red_sedan", "green_sedan", "bus", "purple_bus"],
	"airport": ["tow_tractor", "fuel_tanker", "service_truck", "forklift", "red_truck"],
}

var _roads: Dictionary = {}  # road_name -> {category, points: Array[Vector2]}
var _next_spawn: Dictionary = {}  # road_name -> seconds remaining


func _ready() -> void:
	_reload_roads()
	get_node("../PathLayer").roads_changed.connect(_reload_roads)
	# Roads are traced per airport, so travelling has to drop the old ones and
	# clear any vehicle still driving along a road that no longer exists here.
	Maps.map_changed.connect(_on_map_changed)


# The y-sorted node the cars live in, falling back to this node if it is
# missing so traffic still runs rather than vanishing.
func _layer() -> Node2D:
	var l := get_node_or_null("../Buildings")
	return l if l is Node2D else self


# Only OUR vehicles - the layer also holds the building slots, and clearing
# those on a map change would leave every plot invisible until something else
# rebuilt them.
func _vehicles() -> Array:
	var out: Array = []
	for c in _layer().get_children():
		if c is Sprite2D:
			out.append(c)
	return out


func _on_map_changed(_map_key: String) -> void:
	for vehicle in _vehicles():
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
			# Roads start out of phase with each other, not from a shared
			# zero - otherwise every road on the map spawns its first vehicle
			# in the same instant.
			_next_spawn[road_name] = randf() * MEAN_GAP_SECONDS
	for road_name in _next_spawn.keys().duplicate():
		if not _roads.has(road_name):
			_next_spawn.erase(road_name)


func _process(delta: float) -> void:
	for road_name in _roads.keys():
		_next_spawn[road_name] -= delta
		if _next_spawn[road_name] <= 0.0:
			_next_spawn[road_name] = _next_headway()
			_spawn(_roads[road_name])


# The gap until this road's next vehicle: MIN plus an exponential draw, capped.
# -log(u) with u in (0, 1] is the standard inverse-transform for an exponential;
# 1.0 - randf() keeps u off zero, which would be an infinite gap.
func _next_headway() -> float:
	var u := 1.0 - randf()
	var spread := MEAN_GAP_SECONDS - MIN_GAP_SECONDS
	return minf(MAX_GAP_SECONDS, MIN_GAP_SECONDS - log(u) * spread)


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
	# Parented into the y-sorted world layer, NOT to this node. RoadTraffic sits
	# after Buildings in the scene, so its own children drew on top of every
	# building unconditionally - cars driving over rooftops. As siblings of the
	# building slots inside a y-sorted parent they sort by depth instead: a car
	# lower on screen passes in front, one further up goes behind.
	_layer().add_child(vehicle)
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
