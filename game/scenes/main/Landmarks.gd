extends Node2D

# Draws the fixed scenery placed by LandmarkEditor - the terminal, and whatever
# joins it. Nothing here is interactive: a landmark has no bubble, no cost and
# nothing to collect, so it is scenery that happens to be enormous.
#
# y_sort_enabled on this node is what lets an aircraft taxi in front of the
# terminal and a plot behind it draw behind it. The sprite's origin is the point
# where the building meets the ground, same convention as BuildingSlot, so the
# sort key is the thing actually touching the tarmac rather than the top of a
# control tower.

func _ready() -> void:
	Maps.map_changed.connect(func(_k: String) -> void: rebuild())
	rebuild()


func rebuild() -> void:
	# Out of the tree NOW, not next frame: queue_free is deferred, so moving a
	# landmark drew the old copy on top of the new one until the frame ended.
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for entry in LandmarkLayout.load_data():
		var key := str(entry.get("key", ""))
		var path := LandmarkLayout.texture_path(key)
		if path == "" or not ResourceLoader.exists(path):
			continue
		var s := Sprite2D.new()
		s.texture = load(path)
		s.centered = false
		# Up and left from the ground point, matching BuildingSlot.
		s.offset = Vector2(-s.texture.get_width() * 0.5, -s.texture.get_height())
		s.position = Vector2(float(entry.get("x", 0.0)), float(entry.get("y", 0.0)))
		var k := float(entry.get("scale", 1.0))
		s.scale = Vector2(k, k)
		add_child(s)
