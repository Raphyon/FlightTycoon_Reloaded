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
	for child in get_children():
		child.queue_free()
	for plot in BuildingLayout.load_data():
		var slot := Node2D.new()
		slot.set_script(SLOT_SCRIPT)
		add_child(slot)
		slot.setup(int(plot.get("id", 0)),
			Vector2(float(plot.get("x", 0.0)), float(plot.get("y", 0.0))))
		slot.clicked.connect(_on_slot_clicked)


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
	var panel := get_node_or_null("../UI/PropShopPanel")
	if panel and panel.has_method("open_for_plot"):
		panel.open_for_plot(plot_id)
