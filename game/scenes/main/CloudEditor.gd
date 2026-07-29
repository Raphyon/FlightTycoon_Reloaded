extends Node2D

# Manual placement tool for cloud cover, one point per lockable zone - same
# workflow as ApronEditor (no measured positions exist for these crops, so
# they're eyeballed and placed by hand).
#
#   O          toggle cloud placement mode on/off
#   1-7        pick which area you're placing for (Zone1 has no cloud)
#   left click place/move this area's cloud (click its own cloud to remove)
#
# Saves immediately to res://data/cloud_layout.json.

const CLOUD_SLOT_SCENE := preload("res://scenes/main/CloudSlot.tscn")

var editing := false
var area_index := 1  # Zone2 - first lockable area
var data: Dictionary = {}  # area_name -> [x,y]
var _slots: Dictionary = {}  # area_name -> Node2D


func _ready() -> void:
	data = CloudLayout.load_data()
	ZoneProgress.unlocked_changed.connect(_rebuild_all)
	_rebuild_all()


func _current_area_name() -> String:
	return ApronLayout.AREA_NAMES[area_index]


# Uses _input (fires before GUI, physics picking, and _unhandled_input),
# not _unhandled_input like ApronEditor - a placement click almost always
# lands on an apron underneath (that's the point, clouds cover apron
# areas), and its Area2D would otherwise claim the click via physics
# picking before this node ever saw it, so nothing got placed. Claiming
# the event here first and marking it handled preempts that.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_O:
			editing = !editing
			print("Cloud editor %s - editing %s" % ["ON" if editing else "OFF", _current_area_name()])
		elif editing and event.keycode >= KEY_1 and event.keycode <= KEY_7:
			var idx: int = event.keycode - KEY_1
			if idx < ApronLayout.AREA_NAMES.size():
				area_index = idx
				print("Editing cloud for: %s" % _current_area_name())

	if not editing:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_place(get_global_mouse_position())


func _place(pos: Vector2) -> void:
	var area_name := _current_area_name()
	if not area_name in CloudLayout.LOCKABLE_AREAS:
		print("%s has no cloud (always unlocked)" % area_name)
		return
	# Re-sync with whatever's actually on disk right before writing, rather
	# than trusting this instance's in-memory copy from _ready() - avoids
	# ever blowing away entries this instance doesn't know about.
	data = CloudLayout.load_data()
	data[area_name] = [pos.x, pos.y]
	CloudLayout.save_data(data)
	print("Placed cloud for %s at (%d,%d)" % [area_name, roundi(pos.x), roundi(pos.y)])
	call_deferred("_rebuild_all")


func _rebuild_all() -> void:
	for area_name in _slots.keys().duplicate():
		_slots[area_name].queue_free()
	_slots.clear()
	for area_name in CloudLayout.LOCKABLE_AREAS:
		if ZoneProgress.is_unlocked(area_name) or not data.has(area_name):
			continue
		var p: Array = data[area_name]
		var slot: Node2D = CLOUD_SLOT_SCENE.instantiate()
		get_node("../Clouds").add_child(slot)
		slot.setup(area_name, Vector2(p[0], p[1]))
		slot.clicked.connect(_on_cloud_clicked)
		_slots[area_name] = slot


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
