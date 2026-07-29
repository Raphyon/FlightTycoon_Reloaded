extends Node2D

# In-game apron placement tool for all 7 apron areas, including the starting
# one - one system for everything instead of Zone1 being a special case.
#
#   P          toggle placement mode on/off
#   1-7        pick which area you're editing (order = ApronLayout.AREA_NAMES)
#   left click place an apron exactly where you click (click empty ground to
#              add, click an existing one to remove) - no grid snapping, since
#              not every apron-shaped tile sits on the same lattice.
#
# Also owns which apron each Fleet aircraft is visually parked at: Apron's
# "occupied" is a live reflection of Fleet.get_aircraft_at_apron(), and every
# rebuild re-syncs the actual world sprites to match Fleet's assignment data.
#
# IDs are gap-free across all areas (see ApronLayout.compute_id_starts), so
# any add/remove anywhere rebuilds every area, not just the one being edited.
#
# Changes save immediately to res://data/apron_layout.json - nothing to
# remember to do manually.

const APRON_SLOT_SCENE := preload("res://scenes/main/ApronSlot.tscn")
const ApronSlotScript := preload("res://scenes/main/ApronSlot.gd")
const WORLD_AIRCRAFT_SCENE := preload("res://scenes/main/WorldAircraft.tscn")
const MATCH_RADIUS := 8.0  # px - how close a click has to be to hit an existing point

var editing := false
var area_index := 0
var data: Dictionary = {}
var _slots: Dictionary = {}  # area_name -> {apron_id: Area2D}
var _world_aircraft: Dictionary = {}  # aircraft_id -> Node2D
var _hover_pos := Vector2.ZERO
var _hover_valid := false


func _ready() -> void:
	data = ApronLayout.load_area_data()
	if not data.has("Zone1"):
		data["Zone1"] = ApronLayout.default_zone1_points()
		ApronLayout.save_area_data(data)
	for area_name in ApronLayout.AREA_NAMES:
		_slots[area_name] = {}
	Fleet.fleet_changed.connect(_rebuild_all)
	_rebuild_all()


func get_occupied_position() -> Vector2:
	var starter := Fleet.get_aircraft(1)
	if starter:
		var slot: Area2D = _find_slot(starter.assigned_apron_id)
		if slot:
			return slot.position
	return Vector2.ZERO


func _find_slot(apron_id: int) -> Area2D:
	for area_slots in _slots.values():
		if area_slots.has(apron_id):
			return area_slots[apron_id]
	return null


func _current_area_name() -> String:
	return ApronLayout.AREA_NAMES[area_index]


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_P:
			editing = !editing
			print("Apron editor %s - editing %s" % ["ON" if editing else "OFF", _current_area_name()])
			queue_redraw()
		elif editing and event.keycode >= KEY_1 and event.keycode <= KEY_7:
			var idx: int = event.keycode - KEY_1
			if idx < ApronLayout.AREA_NAMES.size():
				area_index = idx
				print("Editing area: %s" % _current_area_name())

	if not editing:
		return

	if event is InputEventMouseMotion:
		_hover_pos = get_global_mouse_position()
		_hover_valid = true
		queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_add_point(get_global_mouse_position())


# Only adds - a click that lands on an existing apron is handled by that
# ApronSlot's own "clicked" signal (_on_slot_clicked) instead. Checked
# against the actual diamond footprint (matching ApronSlot's collision
# shape), not a small fixed radius - a click anywhere on the visible tile
# needs to count as "already covered", not just clicks within a few pixels
# of dead-center, or an off-centre click meant to remove a tile would also
# get treated as empty ground and add a new one right next to it.
func _add_point(pos: Vector2) -> void:
	var area_name := _current_area_name()
	var list: Array = data.get(area_name, [])
	for p in list:
		if _point_in_apron_footprint(pos, Vector2(float(p[0]), float(p[1]))):
			return
	list.append([pos.x, pos.y])
	print("Added %s (%d,%d)" % [area_name, roundi(pos.x), roundi(pos.y)])
	data[area_name] = list
	ApronLayout.save_area_data(data)
	# Deferred: rebuilding spawns a new pickable Area2D right under the
	# cursor. Doing that synchronously meant the same click could also get
	# picked up by physics picking for the shape that just appeared,
	# triggering an instant remove. Deferring means the new shape doesn't
	# exist until this input event has fully finished being dispatched.
	call_deferred("_rebuild_all")


func _remove_point(pos: Vector2) -> void:
	var area_name := _current_area_name()
	var list: Array = data.get(area_name, [])
	var idx := _find_point(list, pos)
	if idx == -1:
		return
	list.remove_at(idx)
	print("Removed %s (%d,%d)" % [area_name, roundi(pos.x), roundi(pos.y)])
	data[area_name] = list
	ApronLayout.save_area_data(data)
	call_deferred("_rebuild_all")


func _find_point(list: Array, pos: Vector2) -> int:
	for i in range(list.size()):
		var p := Vector2(float(list[i][0]), float(list[i][1]))
		if p.distance_to(pos) < MATCH_RADIUS:
			return i
	return -1


# Diamond point-in-shape test matching ApronSlot's actual collision shape.
func _point_in_apron_footprint(pos: Vector2, center: Vector2) -> bool:
	var d := (pos - center).abs()
	var hw := ApronSlotScript.SIZE.x * 0.5
	var hh := ApronSlotScript.SIZE.y * 0.5
	return (d.x / hw + d.y / hh) <= 1.0


func _rebuild_all() -> void:
	var starts: Dictionary = ApronLayout.compute_id_starts(data)
	for area_name in ApronLayout.AREA_NAMES:
		_rebuild(area_name, starts[area_name])
	_sync_world_aircraft()


func _rebuild(area_name: String, start_id: int) -> void:
	for slot in _slots[area_name].values():
		slot.queue_free()
	_slots[area_name].clear()

	var points: Array = data.get(area_name, [])
	for apron in ApronLayout.build_area_aprons(points, start_id, area_name):
		apron.occupied = Fleet.get_aircraft_at_apron(apron.id) != null
		var slot: Area2D = APRON_SLOT_SCENE.instantiate()
		get_node("../Aprons").add_child(slot)
		slot.setup(apron)
		# Removing an existing apron is driven by its own click detection
		# (this signal), not by _unhandled_input - see _add_point.
		slot.clicked.connect(_on_slot_clicked.bind(area_name))
		_slots[area_name][apron.id] = slot


# Aircraft states where the plane is away from its home apron - flying, or
# sitting at the destination - so it shouldn't render there.
const _AWAY_STATES := [
	FleetAircraft.State.FLYING_OUT,
	FleetAircraft.State.AWAITING_DEST_CLAIM,
	FleetAircraft.State.AWAITING_DEST_REFUEL,
	FleetAircraft.State.FLYING_BACK,
]


# Keeps the actual world sprites in sync with Fleet's assignment data -
# spawns one per assigned aircraft that's actually home, positioned at its
# apron, and removes any that got unassigned, no longer exist, or just
# departed.
func _sync_world_aircraft() -> void:
	var seen := {}
	for a in Fleet.aircraft:
		if a.is_idle() or a.state in _AWAY_STATES:
			continue
		var slot: Area2D = _find_slot(a.assigned_apron_id)
		if not slot:
			continue
		seen[a.id] = true
		if not _world_aircraft.has(a.id):
			var node := WORLD_AIRCRAFT_SCENE.instantiate()
			get_node("../WorldAircraft").add_child(node)
			node.setup(a.model_key, slot.position)
			_world_aircraft[a.id] = node
			# A plane appearing straight out of a return flight flies the
			# traced approach in rather than blinking onto the apron. Any
			# other first appearance (a fresh assignment) just parks.
			if a.state == FleetAircraft.State.AWAITING_HOME_CLAIM:
				node.play_arrival()
		else:
			# Not setup() - that adds a fresh set of child sprites every
			# call, so re-running it each rebuild stacked duplicates.
			_world_aircraft[a.id].sync_position(slot.position)

	for aircraft_id in _world_aircraft.keys().duplicate():
		if not seen.has(aircraft_id):
			# Play the shrink/fade-out before freeing rather than an instant
			# removal - see WorldAircraft.play_departure(). Dropped from
			# _world_aircraft immediately either way so a quick reassignment
			# can spawn a fresh node instead of fighting the departing one.
			_world_aircraft[aircraft_id].play_departure()
			_world_aircraft.erase(aircraft_id)


func _on_slot_clicked(apron: Apron, area_name: String) -> void:
	# While placing clouds, a click almost always lands on an apron
	# underneath (that's the point - clouds cover apron areas), which would
	# otherwise pop the apron info panel or trigger an assign on top of
	# whatever CloudEditor is doing with that same click. Ignore it here.
	if get_node("../CloudEditor").editing:
		return
	if editing and area_name == _current_area_name():
		_remove_point(apron.screen_pos)
	else:
		get_node("../UI/ApronInfoPanel").show_apron(apron)


func _draw() -> void:
	if not editing or not _hover_valid:
		return
	# Match ApronSlot's actual footprint (smaller than the full tile
	# spacing), not the full tile size.
	var hw := ApronSlotScript.SIZE.x * 0.5
	var hh := ApronSlotScript.SIZE.y * 0.5
	var pts := PackedVector2Array([
		_hover_pos + Vector2(0, -hh), _hover_pos + Vector2(hw, 0),
		_hover_pos + Vector2(0, hh), _hover_pos + Vector2(-hw, 0),
	])
	draw_colored_polygon(pts, Color(1, 1, 0, 0.35))
