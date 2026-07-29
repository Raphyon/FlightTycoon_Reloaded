class_name PathLayout
extends RefCounted

# Generic traced paths, all placed by hand with PathEditor - no measured/
# guessed/derived positions. Every path is just an ordered list of [x, y]
# points; a click always appends a point connected to the previous one.
#
# {
#   "plane_body": [[x,y], ...],    - the departing plane's own path
#   "plane_shadow": [[x,y], ...],  - its shadow's path (can differ so the
#                                    shadow stays on the ground while the
#                                    body climbs - see WorldAircraft)
#   "plane_arrival_body": [...],   - the landing approach, traced separately
#   "plane_arrival_shadow": [...],   rather than just replaying the departure
#                                    backwards, so planes can come in on
#                                    their own line
#   "roads": {
#     "<name>": {"category": "airport" | "commercial", "points": [[x,y], ...]}
#   }
# }
const SAVE_PATH := "res://data/paths.json"
const PLANE_PATH_KEYS := [
	"plane_body", "plane_shadow", "plane_arrival_body", "plane_arrival_shadow"
]


static func load_data() -> Dictionary:
	var data: Dictionary = {}
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		var text := f.get_as_text()
		f.close()
		var parsed: Variant = JSON.parse_string(text)
		if parsed is Dictionary:
			data = parsed
	for key in PLANE_PATH_KEYS:
		data[key] = data.get(key, [])
	data["roads"] = data.get("roads", {})
	return data


static func save_data(data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


static func points_to_vectors(points: Array) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p in points:
		if p is Array and p.size() == 2:
			out.append(Vector2(float(p[0]), float(p[1])))
	return out


# u is progress (0..1) along the whole polyline, weighted by distance so a
# single eased "u" tween produces continuous speed across every waypoint -
# only the heading changes at a waypoint, not the pace. Shared by
# WorldAircraft (plane/shadow tracks) and road traffic (arbitrary-length
# road paths).
static func position_along_path(points: Array[Vector2], u: float) -> Vector2:
	if points.is_empty():
		return Vector2.ZERO
	if points.size() == 1:
		return points[0]
	var seg_lengths: Array[float] = []
	var total := 0.0
	for i in range(points.size() - 1):
		var d := points[i].distance_to(points[i + 1])
		seg_lengths.append(d)
		total += d
	if total <= 0.0:
		return points[0]
	var target := clampf(u, 0.0, 1.0) * total
	var travelled := 0.0
	for i in range(seg_lengths.size()):
		var seg := seg_lengths[i]
		if target <= travelled + seg or i == seg_lengths.size() - 1:
			var local_u := (target - travelled) / seg if seg > 0.0 else 0.0
			return points[i].lerp(points[i + 1], clampf(local_u, 0.0, 1.0))
		travelled += seg
	return points[-1]


# Direction of travel at the same progress u used by position_along_path -
# same segment lookup, but returns the segment's heading instead of a
# point. Used to pick which isometric-facing sprite variant to show (see
# RoadTraffic) since a bent path can face a different way partway through.
static func direction_along_path(points: Array[Vector2], u: float) -> Vector2:
	if points.size() < 2:
		return Vector2.RIGHT
	var seg_lengths: Array[float] = []
	var total := 0.0
	for i in range(points.size() - 1):
		var d := points[i].distance_to(points[i + 1])
		seg_lengths.append(d)
		total += d
	if total <= 0.0:
		return (points[1] - points[0]).normalized()
	var target := clampf(u, 0.0, 1.0) * total
	var travelled := 0.0
	for i in range(seg_lengths.size()):
		var seg := seg_lengths[i]
		if target <= travelled + seg or i == seg_lengths.size() - 1:
			return (points[i + 1] - points[i]).normalized()
		travelled += seg
	return (points[-1] - points[-2]).normalized()
