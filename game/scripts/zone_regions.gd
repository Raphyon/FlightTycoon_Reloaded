class_name ZoneRegions
extends RefCounted

# The SHAPE of each zone on the ground, as a polygon drawn by hand in game.
#
# Aprons already know their zone because the apron editor asks which area you
# are placing into. Nothing else does. Building plots are just an id and a
# position, so "which zone is this plot in" had no answer - and with all 42 of
# them in one district south-west of Zone1, there was no sensible way to invent
# one either. Every plot became reachable the moment Zone2 was bought, which is
# why an airport's whole city fills up in two hours.
#
# Drawing the regions once answers it for everything at once, and it is the
# honest way round: a zone is a piece of the map, so say where it is and let
# what sits inside follow.
#
#     {map_key: {"Zone2": [[x, y], [x, y], ...]}}
#
# A region with fewer than three points is ignored - it cannot contain anything.
const SAVE_PATH := "res://data/zone_regions.json"


static func load_all() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


static func save_all(all_data: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("res://data")
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(all_data, "\t"))
	f.close()


# {area_name: PackedVector2Array} for one airport.
static func load_data(map_key: String = "") -> Dictionary:
	var key := map_key if map_key != "" else Maps.current
	var raw: Variant = load_all().get(key, {})
	var out := {}
	if raw is Dictionary:
		for area_name in raw:
			var pts := PackedVector2Array()
			for p in raw[area_name]:
				pts.append(Vector2(float(p[0]), float(p[1])))
			out[area_name] = pts
	return out


static func save_data(data: Dictionary, map_key: String = "") -> void:
	var key := map_key if map_key != "" else Maps.current
	var all_data := load_all()
	var plain := {}
	for area_name in data:
		var list: Array = []
		for v in data[area_name]:
			list.append([v.x, v.y])
		plain[area_name] = list
	all_data[key] = plain
	save_all(all_data)


# Which zone this point sits in, or "" if it is outside every drawn region.
#
# Deliberately returns "" rather than guessing at a nearest zone: an unassigned
# plot should read as UNDRAWN so it can be fixed, not be quietly filed somewhere
# plausible. Callers decide what to do with the gap - see
# BuildingProgress.plot_is_available, which treats "" as always available so a
# half-drawn map still plays.
static func area_at(point: Vector2, map_key: String = "") -> String:
	for area_name in load_data(map_key):
		var poly: PackedVector2Array = load_data(map_key)[area_name]
		if poly.size() >= 3 and Geometry2D.is_point_in_polygon(point, poly):
			return str(area_name)
	return ""


# One pass over the plots rather than one lookup each - area_at reloads the
# file every call, and the camera asks this every time a zone is bought.
static func areas_for_points(points: Array, map_key: String = "") -> Array:
	var regions := load_data(map_key)
	var out: Array = []
	for p in points:
		var found := ""
		for area_name in regions:
			var poly: PackedVector2Array = regions[area_name]
			if poly.size() >= 3 and Geometry2D.is_point_in_polygon(p, poly):
				found = str(area_name)
				break
		out.append(found)
	return out
