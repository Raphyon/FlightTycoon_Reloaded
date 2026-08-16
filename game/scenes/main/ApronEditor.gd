extends Node2D

# In-game apron placement tool for all 7 apron areas, including the starting
# one - one system for everything instead of Zone1 being a special case.
#
#   Switched on from the F1 menu - no toggle key, see _unhandled_input.
#   1-7        pick which area you're editing (order = Maps.areas_for(),
#              i.e. the areas of the airport you're currently standing in)
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

# A SETTER, not a plain flag. The F1 menu switches editors by assigning to this
# directly (DebugMenu._on_editor_toggled), so anything that has to happen when
# the tool goes away has to hang off the assignment.
#
# Without it the tool DID switch off - every handler is guarded on `editing` -
# but nothing redrew, so its on-screen readout stayed up and it looked like the
# thing would not close. LandmarkEditor and ZoneEditor were fixed when this bit
# the first time; these five were not.
var editing := false:
	set(value):
		if editing == value:
			return
		editing = value
		if is_inside_tree():
			_update_hud()
			queue_redraw()
var area_index := 0
var data: Dictionary = {}
var _slots: Dictionary = {}  # area_name -> {apron_id: Area2D}
var _world_aircraft: Dictionary = {}  # aircraft_id -> Node2D
var _hud: EditorHud
var _hover_pos := Vector2.ZERO
var _hover_valid := false


func _ready() -> void:
	# Pre-fills homeland's Zone1 and the robot airport's mirror of it, whichever
	# airport we happen to boot into.
	ApronLayout.ensure_seeded()
	# A FLEET CHANGE IS NOT A LAYOUT CHANGE. This used to call _request_rebuild,
	# which frees and recreates every apron slot - and a fleet change fires
	# whenever ANY aircraft anywhere lands, claims or departs, which at a full
	# airport is constantly.
	#
	# That quietly destroyed anything a slot was in the middle of. The two
	# second claim swoop (ProgressBubble) would vanish part-filled the moment an
	# unrelated aircraft touched down somewhere else on the map, which read as
	# the progress bars simply not working.
	#
	# What actually changes is occupancy and state, and a slot can redraw for
	# that. The full rebuild is still there for when the apron SET changes -
	# buying a pad, travelling - which is what it was for.
	Fleet.fleet_changed.connect(_refresh_slots)
	_hud = EditorHud.create(self)
	reload_for_map()


# Re-reads this airport's aprons and rebuilds from scratch. Called on travel:
# `data` and `_slots` are per-map, so a plain _rebuild_all() after a map change
# would redraw the airport you just left (it renders the in-memory data) and
# blow up on any area the previous map didn't have.
# Which airport, which area, and how many aprons sit in each - the counts are
# what tell you whether you've actually placed into the area you meant, since
# the area names on the newer maps are provisional and easy to lose track of.
func _update_hud() -> void:
	if _hud == null:
		return
	var areas := _areas()
	var lines: Array = [
		"APRON EDITOR - %s  (F1 to switch off)" % Maps.display_name(),
		"",
	]
	var total := 0
	for i in range(areas.size()):
		var area_name: String = areas[i]
		var count: int = (data.get(area_name, []) as Array).size()
		total += count
		lines.append("%s %d  %-14s %3d" % [">" if i == area_index else " ", i + 1, area_name, count])
	lines.append("")
	lines.append("%d aprons on this map   ·   1-%d = area" % [total, areas.size()])
	lines.append("click ground = add   ·   click a tile = remove")
	_hud.set_lines(editing, lines)


func reload_for_map() -> void:
	for area_name in _slots.keys():
		for slot in _slots[area_name].values():
			slot.queue_free()
	_slots.clear()
	for area_name in _areas():
		_slots[area_name] = {}
	# Travelling is not a departure. _sync_world_aircraft plays a takeoff
	# animation for any aircraft it stops seeing, which is right when one is
	# dispatched and wrong when the whole airport changes underneath it - every
	# plane at the airport we just left would fly off. Freeing them outright
	# here means the new airport's sync starts from nothing.
	for node in _world_aircraft.values():
		node.queue_free()
	_world_aircraft.clear()

	# Effective, so a destination that borrows another's pads still draws them.
	# Editing one is refused rather than silently forking it - see _can_edit.
	data = ApronLayout.effective_area_data()
	area_index = 0
	_update_hud()
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


func _areas() -> Array:
	return Maps.areas_for()


func _current_area_name() -> String:
	var areas := _areas()
	return areas[area_index] if area_index < areas.size() else ""


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# NO TOGGLE KEY. Every tool was holding a letter hostage across the
		# whole game - P, O, T, R, G, L, Z - and two of them collided (G was
		# both this and the grid overlay). They are switched on from the F1
		# menu now, which is the only debug key left. The keys BELOW still
		# work, but only while this tool is on, so they cost nothing.
		if editing and event.keycode >= KEY_1 and event.keycode <= KEY_7:
			var idx: int = event.keycode - KEY_1
			if idx < _areas().size():
				area_index = idx
				_update_hud()

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
	if not _can_edit():
		return
	var area_name := _current_area_name()
	var list: Array = data.get(area_name, [])
	for p in list:
		if _point_in_apron_footprint(pos, Vector2(float(p[0]), float(p[1]))):
			return
	list.append([pos.x, pos.y])
	print("Added %s (%d,%d)" % [area_name, roundi(pos.x), roundi(pos.y)])
	data[area_name] = list
	ApronLayout.save_area_data(data)
	_update_hud()
	# Deferred: rebuilding spawns a new pickable Area2D right under the
	# cursor. Doing that synchronously meant the same click could also get
	# picked up by physics picking for the shape that just appeared,
	# triggering an instant remove. Deferring means the new shape doesn't
	# exist until this input event has fully finished being dispatched.
	call_deferred("_rebuild_all")


func _remove_point(pos: Vector2) -> void:
	if not _can_edit():
		return
	var area_name := _current_area_name()
	var list: Array = data.get(area_name, [])
	var idx := _find_point(list, pos)
	if idx == -1:
		return
	list.remove_at(idx)
	print("Removed %s (%d,%d)" % [area_name, roundi(pos.x), roundi(pos.y)])
	data[area_name] = list
	ApronLayout.save_area_data(data)
	_update_hud()
	call_deferred("_rebuild_all")


# A map that borrows its pads (the further robot destinations) has none of its
# own, so `data` here is someone else's. Saving it would write all 110 borrowed
# points into this map's slot and fork the copy the borrow exists to avoid, and
# the first edit is exactly when that happens. Refused with a reason rather than
# quietly ignored - the tool is the user's, and silence would read as a bug.
func _can_edit() -> bool:
	var source: String = str(Maps.entry().get("aprons_from", ""))
	if source == "":
		return true
	print("%s borrows its pads from %s - edit them there."
		% [Maps.display_name(), Maps.display_name(source)])
	return false


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


var _rebuild_queued := false


# Update what the existing slots show, without replacing them.
func _refresh_slots() -> void:
	for area_name in _slots:
		for apron_id in _slots[area_name]:
			var slot = _slots[area_name][apron_id]
			if not is_instance_valid(slot):
				continue
			slot.apron.occupied = (Fleet.get_aircraft_at_apron(apron_id) != null
				or Fleet.get_aircraft_at_robot_apron(apron_id) != null)
			slot.queue_redraw()
	_sync_world_aircraft()


func _request_rebuild() -> void:
	if _rebuild_queued:
		return
	_rebuild_queued = true
	call_deferred("_do_queued_rebuild")


func _do_queued_rebuild() -> void:
	_rebuild_queued = false
	_rebuild_all()


func _rebuild_all() -> void:
	var starts: Dictionary = ApronLayout.compute_id_starts()
	for area_name in _areas():
		_rebuild(area_name, starts[area_name])
	_sync_world_aircraft()


func _rebuild(area_name: String, start_id: int) -> void:
	for slot in _slots[area_name].values():
		slot.queue_free()
	_slots[area_name].clear()

	var points: Array = data.get(area_name, [])
	for apron in ApronLayout.build_area_aprons(points, start_id, area_name):
		# A robot pad is occupied by whoever landed on it, not by anything with
		# this as its home apron - the two id spaces don't overlap, so asking
		# both is safe and covers either airport.
		apron.occupied = (Fleet.get_aircraft_at_apron(apron.id) != null
			or Fleet.get_aircraft_at_robot_apron(apron.id) != null)
		var slot: Area2D = APRON_SLOT_SCENE.instantiate()
		get_node("../Aprons").add_child(slot)
		slot.setup(apron)
		# Removing an existing apron is driven by its own click detection
		# (this signal), not by _unhandled_input - see _add_point.
		slot.clicked.connect(_on_slot_clicked.bind(area_name))
		_slots[area_name][apron.id] = slot


# Which pad this aircraft is physically sitting on right now, or -1 if it
# shouldn't be drawn at all. Dispatched aircraft used to be simply hidden;
# they're really at the robot airport now, on the pad they claimed, so the id
# depends on where in the trip they are. Returning an id from another airport is
# fine - _find_slot only knows the current map's pads, so it comes back null and
# the aircraft isn't drawn here.
func _visible_apron_for(a: FleetAircraft) -> int:
	if a.is_idle() or a.is_in_transit():
		return -1
	if a.is_at_robot():
		return a.robot_apron_id
	return a.assigned_apron_id


# Keeps the actual world sprites in sync with Fleet's assignment data -
# spawns one per assigned aircraft that's actually home, positioned at its
# apron, and removes any that got unassigned, no longer exist, or just
# departed.
func _sync_world_aircraft() -> void:
	var seen := {}
	for a in Fleet.aircraft:
		var apron_id := _visible_apron_for(a)
		if apron_id == -1:
			continue
		var slot: Area2D = _find_slot(apron_id)
		if not slot:
			continue
		seen[a.id] = true
		if not _world_aircraft.has(a.id):
			var node := WORLD_AIRCRAFT_SCENE.instantiate()
			get_node("../WorldAircraft").add_child(node)
			node.setup(a.model_key, slot.position, a.livery)
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
			# A livery bought or switched while the aircraft is already parked
			# has to repaint the node that exists, because setup() is never
			# called again for it.
			_world_aircraft[a.id].set_livery(a.livery)

	for aircraft_id in _world_aircraft.keys().duplicate():
		if not seen.has(aircraft_id):
			# Play the shrink/fade-out before freeing rather than an instant
			# removal - see WorldAircraft.play_departure(). Dropped from
			# _world_aircraft immediately either way so a quick reassignment
			# can spawn a fresh node instead of fighting the departing one.
			# The hold the aircraft was given when it was dispatched, so the
			# animation and the flight clock agree (Fleet.BULK_LAUNCH_STAGGER).
			var departing := Fleet.get_aircraft(aircraft_id)
			# TAKING OFF IS AN ANIMATION; BEING TAKEN OFF THE PAD IS NOT.
			# This fired for anything that stopped being visible, so deleting a
			# route - or selling an aircraft - played a full takeoff roll for a
			# machine that went to the hangar, or that no longer exists at all.
			# Only something actually in the air departs.
			if departing == null or not departing.is_in_transit():
				_world_aircraft[aircraft_id].queue_free()
				_world_aircraft.erase(aircraft_id)
				continue
			# The hold the aircraft was given when it was dispatched, so the
			# animation and the flight clock agree (Fleet.BULK_LAUNCH_STAGGER).
			var hold: float = departing.launch_delay
			departing.launch_delay = 0.0
			_world_aircraft[aircraft_id].play_departure(hold)
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
