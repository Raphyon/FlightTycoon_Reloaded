extends Node2D

# Manual placement tool for cloud cover, one point per lockable zone - same
# workflow as ApronEditor (no measured positions exist for these crops, so
# they're eyeballed and placed by hand).
#
#   Switched on from the F1 menu - no toggle key, see _input.
#   1-n        pick which area you're placing for - the current airport's
#              areas (7 on homeland, 3 on Dreamland, 1 on the carrier). Not
#              every area has cloud art; the on-screen readout says which.
#   left click place/move this area's cloud (click its own cloud to remove)
#
# Saves immediately to res://data/cloud_layout.json.

const CLOUD_SLOT_SCENE := preload("res://scenes/main/CloudSlot.tscn")

var _click := ClickDrag.new()
var editing := false
var area_index := 0  # reset per map by reload_for_map()
var data: Dictionary = {}  # area_name -> [x,y]
var _slots: Dictionary = {}  # area_name -> Node2D
var _hud: EditorHud


func _ready() -> void:
	ZoneProgress.unlocked_changed.connect(_rebuild_all)
	_hud = EditorHud.create(self)
	reload_for_map()


# Clouds are per-airport too, so travelling has to re-read rather than redraw
# what's already in memory. _rebuild_all already frees every slot, so this only
# has to refresh `data` first.
# Clouds only exist for areas that have cloud art, and only show while the area
# is still locked - so the readout says which of those two is stopping you,
# rather than leaving a click looking like it silently did nothing.
func _update_hud() -> void:
	if _hud == null:
		return
	var areas := Maps.areas_for()
	var lockable := CloudLayout.lockable_areas()
	var lines: Array = [
		"CLOUD EDITOR - %s  (F1 to switch off)" % Maps.display_name(),
		"",
	]
	for i in range(areas.size()):
		var area_name: String = areas[i]
		var state := ""
		if not area_name in lockable:
			state = "no cloud art"
		elif ZoneProgress.is_unlocked(area_name):
			state = "unlocked - cloud hidden"
		elif data.has(area_name):
			var p: Array = data[area_name]
			state = "placed (%d,%d)" % [roundi(float(p[0])), roundi(float(p[1]))]
		else:
			state = "NOT PLACED"
		lines.append("%s %d  %-14s %s" % [">" if i == area_index else " ", i + 1, area_name, state])
	lines.append("")
	lines.append("1-%d = area   ·   click = place/move   ·   click its cloud = remove" % areas.size())
	_hud.set_lines(editing, lines)


func reload_for_map() -> void:
	data = CloudLayout.load_data()
	# Start on the first area that actually has cloud art rather than on area
	# 1: on homeland that's Zone1, which has no cloud by design, so opening the
	# tool would land you on the one area where clicking does nothing.
	var areas := Maps.areas_for()
	var lockable := CloudLayout.lockable_areas()
	area_index = 0
	for i in range(areas.size()):
		if areas[i] in lockable:
			area_index = i
			break
	_update_hud()
	_rebuild_all()


func _current_area_name() -> String:
	var areas := Maps.areas_for()
	return areas[area_index] if area_index < areas.size() else ""


# Uses _input (fires before GUI, physics picking, and _unhandled_input),
# not _unhandled_input like ApronEditor - a placement click almost always
# lands on an apron underneath (that's the point, clouds cover apron
# areas), and its Area2D would otherwise claim the click via physics
# picking before this node ever saw it, so nothing got placed. Claiming
# the event here first and marking it handled preempts that.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# NO TOGGLE KEY. Every tool was holding a letter hostage across the
		# whole game - P, O, T, R, G, L, Z - and two of them collided (G was
		# both this and the grid overlay). They are switched on from the F1
		# menu now, which is the only debug key left. The keys BELOW still
		# work, but only while this tool is on, so they cost nothing.
		if editing and event.keycode >= KEY_1 and event.keycode <= KEY_7:
			var idx: int = event.keycode - KEY_1
			if idx < Maps.areas_for().size():
				area_index = idx
				_update_hud()

	if not editing:
		return
	# Release-click, nothing swallowed - see ClickDrag for why the press must
	# reach the camera.
	if _click.completed(event):
		_place(get_global_mouse_position())


func _place(pos: Vector2) -> void:
	var area_name := _current_area_name()
	if not area_name in CloudLayout.lockable_areas():
		print("%s has no cloud (always unlocked)" % area_name)
		return
	# Re-sync with whatever's actually on disk right before writing, rather
	# than trusting this instance's in-memory copy from _ready() - avoids
	# ever blowing away entries this instance doesn't know about.
	data = CloudLayout.load_data()
	data[area_name] = [pos.x, pos.y]
	CloudLayout.save_data(data)
	print("Placed cloud for %s at (%d,%d)" % [area_name, roundi(pos.x), roundi(pos.y)])
	_update_hud()
	call_deferred("_rebuild_all")


func _rebuild_all() -> void:
	for area_name in _slots.keys().duplicate():
		_slots[area_name].queue_free()
	_slots.clear()

	# An airport that borrows another's cloud positions covers everything
	# outside its own zone permanently - ZoneProgress has no say, because those
	# regions were never purchasable here (see Maps "cloud_cover_from").
	var cover_from: String = Maps.entry().get("cloud_cover_from", "")
	if cover_from != "":
		var borrowed := CloudLayout.load_data(cover_from)
		for area_name in CloudLayout.lockable_areas(cover_from):
			if not borrowed.has(area_name):
				continue
			# The robot's airport mirrors yours pad for pad, so a region there
			# is under cloud exactly while the region it mirrors is still
			# locked for you - your aircraft land on the same aprons you own.
			# Covering everything outside the first zone (which is what this
			# did when the robot had only one) would now hide pads your fleet
			# is actually using.
			if _mirrored_area_unlocked(area_name):
				continue
			var bp: Array = borrowed[area_name]
			var cover: Node2D = CLOUD_SLOT_SCENE.instantiate()
			get_node("../Clouds").add_child(cover)
			cover.setup(area_name, Vector2(bp[0], bp[1]))
			_slots[area_name] = cover
		_apply_pickable()
		return

	for area_name in CloudLayout.lockable_areas():
		if ZoneProgress.is_unlocked(area_name) or not data.has(area_name):
			continue
		var p: Array = data[area_name]
		var slot: Node2D = CLOUD_SLOT_SCENE.instantiate()
		get_node("../Clouds").add_child(slot)
		slot.setup(area_name, Vector2(p[0], p[1]))
		slot.clicked.connect(_on_cloud_clicked)
		_slots[area_name] = slot
	_apply_pickable()


# Covers take clicks only while they're being placed - see CloudSlot.set_pickable.
func _apply_pickable() -> void:
	for slot in _slots.values():
		if is_instance_valid(slot):
			slot.set_pickable(editing)


# A borrowed cover hides the region it was drawn for. On the robot that region
# mirrors one of yours, so it lifts when you unlock the original.
func _mirrored_area_unlocked(borrowed_area: String) -> bool:
	if not Maps.is_robot_map():
		return false
	return ZoneProgress.is_unlocked(borrowed_area)


# Only the placement tool cares about cloud clicks now. Zones are bought in
# the expansion shop, so a cloud is purely the "this area is locked" cover -
# clicking it during normal play does nothing, and it still swallows the
# click so nothing underneath reacts either.
func _on_cloud_clicked(area_name: String) -> void:
	if editing and area_name == _current_area_name():
		data = CloudLayout.load_data()
		data.erase(area_name)
		CloudLayout.save_data(data)
		call_deferred("_rebuild_all")
