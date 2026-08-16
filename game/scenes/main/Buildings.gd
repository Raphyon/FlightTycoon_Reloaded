extends Node2D

# Draws one BuildingSlot per authored plot and keeps them in step with what the
# player has built. y_sort_enabled on this node is what makes a building placed
# further down the screen draw in front of one behind it - which the Eiffel
# Tower at 336px tall depends on entirely.

signal plot_clicked(plot_id: int)

const SLOT_SCRIPT := preload("res://scenes/main/BuildingSlot.gd")


# Rent timers are minutes to hours long, so the callouts only need checking
# every few seconds - polling this every frame across a full airport would be
# pure waste for a state that changes at most once a cycle.
const TICK_SECONDS := 2.0

var _tick := 0.0


func _ready() -> void:
	BuildingProgress.built_changed.connect(_refresh_all)
	BuildingProgress.rent_changed.connect(_refresh_all)
	# Plots appear with Zone2 - see BuildingProgress.buildings_unlocked.
	ZoneProgress.unlocked_changed.connect(rebuild)
	# TRAVELLING IS A REBUILD. Without this the slots from the airport you left
	# stayed on screen - homeland's 42 plots standing at homeland's coordinates
	# over Dreamland's background, which read as the plots having been copied
	# there. They were never cleared. BuildingLayout has plots for homeland
	# only, so rebuilding on arrival correctly leaves the other maps empty.
	Maps.map_changed.connect(func(_key: String) -> void: rebuild())
	rebuild()


func _process(delta: float) -> void:
	_tick += delta
	if _tick < TICK_SECONDS:
		return
	_tick = 0.0
	_refresh_all()


# Full rebuild - plots changed (the editor placed or deleted one) or the map
# did. Buying a building only needs _refresh_all, which is much cheaper.
func rebuild() -> void:
	# Cars live in here too and are not ours to free - see RoadTraffic._layer.
	for child in get_children():
		if not (child is Sprite2D):
			child.queue_free()
	# ONLY THE PLOTS WHOSE ZONE YOU OWN. All 42 used to be drawn at once, which
	# put construction sites across ground the camera will not even travel to -
	# and made the whole city appear the moment one zone was bought. A plot in a
	# locked zone is not scenery, it is a thing you have not unlocked yet.
	for plot in BuildingLayout.load_data():
		if not BuildingProgress.plot_is_available(int(plot.get("id", 0))):
			continue
		var slot := Node2D.new()
		slot.set_script(SLOT_SCRIPT)
		add_child(slot)
		slot.setup(int(plot.get("id", 0)),
			Vector2(float(plot.get("x", 0.0)), float(plot.get("y", 0.0))),
			str(plot.get("site", "buildings")))
		slot.clicked.connect(_on_slot_clicked)
		slot.body_clicked.connect(_on_slot_body_clicked)


func _refresh_all() -> void:
	for child in get_children():
		if child.has_method("refresh"):
			child.refresh()


# One tap does whatever the site needs: an empty one opens the Prop Shop for
# itself (the walkthrough's flow - tap the cone, the business menu opens for
# that plot), a building with rent up collects it, and one still earning does
# nothing.
func _on_slot_clicked(plot_id: int) -> void:
	plot_clicked.emit(plot_id)
	if BuildingProgress.is_built(plot_id):
		BuildingProgress.collect_rent(plot_id)
		return
	_open_shop(plot_id)


# Tapping the building itself opens ITS OWN window - what it earns, who lives
# there, and the one thing you can do about it. The Prop Shop is for empty
# sites; a destructive action does not belong in a window full of buy buttons.
func _on_slot_body_clicked(plot_id: int) -> void:
	plot_clicked.emit(plot_id)
	var panel := get_node_or_null("../UI/BuildingInfoPanel")
	if panel and panel.has_method("show_plot"):
		panel.show_plot(plot_id)


func _open_shop(plot_id: int) -> void:
	var panel := get_node_or_null("../UI/PropShopPanel")
	if panel and panel.has_method("open_for_plot"):
		panel.open_for_plot(plot_id)
