extends PanelContainer

# The Prop Shop - what you put on a construction site.
#
# Built on the aircraft shop, deliberately: same card, same paging, same
# background, so the two screens read as one shop rather than two games. The
# only real difference is that this one is always opened FOR A PLOT.
#
# The walkthrough's flow is that you tap a cone on an empty site and the
# business menu opens for it, so the plot is chosen first and the building
# second; the hub's Prop Shop button is a shortcut that picks the first free
# site rather than a different way in. That's why there is no
# browse-then-choose-a-plot mode - it would be a second flow doing one job.
const BUILDING_ITEM_SCENE := preload("res://scenes/main/BuildingItem.tscn")
const ITEMS_PER_PAGE := 4

@onready var _card_row: HBoxContainer = $Frame/SafeArea/Margin/VBox/CardRow
@onready var _title: Label = $Frame/SafeArea/Margin/VBox/TitleLabel
@onready var _dots: HBoxContainer = $Frame/SafeArea/Margin/VBox/PageControls/Dots
const ARROW_DIM := Color(1, 1, 1, 0.35)

@onready var _prev_button: TextureButton = $Frame/SafeArea/Margin/VBox/PageControls/PrevButton
@onready var _next_button: TextureButton = $Frame/SafeArea/Margin/VBox/PageControls/NextButton
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton

var _plot_id: int = -1
var _items: Array = []
var _page := 0


func _ready() -> void:
	visible = false
	_close_button.pressed.connect(hide)
	# The reference uses a bottom-right arrow, not a full-width bar.
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	_prev_button.pressed.connect(func() -> void: _show_page(_page - 1))
	_next_button.pressed.connect(func() -> void: _show_page(_page + 1))
	Economy.money_changed.connect(_refresh_items)
	Coins.coins_changed.connect(_refresh_items)
	Progression.level_changed.connect(_refresh_items)

	for entry in BuildingLayout.BUILDINGS:
		var item := BUILDING_ITEM_SCENE.instantiate()
		item.setup(str(entry["key"]))
		item.build_pressed.connect(_on_build_pressed)
		_items.append(item)

	_build_dots()
	_show_page(0)

	get_tree().root.size_changed.connect(_fit_content)


func open_for_plot(plot_id: int) -> void:
	if not BuildingProgress.buildings_unlocked():
		return
	# An occupied site has nothing to offer here - what you can do to one is
	# demolish it, and that has its own window now (BuildingInfoPanel).
	if BuildingProgress.is_built(plot_id):
		return
	_plot_id = plot_id
	_title.text = "Prop Shop  -  site %d" % plot_id
	move_to_front()
	visible = true
	_refresh_items()
	call_deferred("_fit_content")


# The hub button's shortcut: first site with nothing on it.
func open_for_first_free_plot() -> bool:
	if not BuildingProgress.buildings_unlocked():
		return false
	for plot in BuildingLayout.load_data():
		var id := int(plot.get("id", 0))
		if not BuildingProgress.is_built(id):
			open_for_plot(id)
			return true
	return false


# Buying used to close the shop, which made kitting out an airport a loop of
# find-a-site, open, buy, closed, find-the-next-site. Nobody builds one
# building. It now walks to the next empty site and stays open, so the shop can
# be held down until the airport is full or the money runs out - and only
# closes when there is genuinely nothing left to build on.
func _on_build_pressed(building_key: String) -> void:
	if _plot_id < 0:
		return
	if not BuildingProgress.build(_plot_id, building_key):
		return
	var next := _next_free_plot(_plot_id)
	if next < 0:
		hide()
		return
	open_for_plot(next)


# The next empty site after this one, wrapping - so building on the last plot
# carries on from the front rather than stopping.
func _next_free_plot(after: int) -> int:
	var ids: Array = []
	for plot in BuildingLayout.load_data():
		ids.append(int(plot.get("id", 0)))
	ids.sort()
	var start := ids.find(after)
	for i in range(ids.size()):
		var id: int = ids[(start + 1 + i) % ids.size()]
		if not BuildingProgress.is_built(id):
			return id
	return -1


func _page_count() -> int:
	return maxi(1, ceili(float(_items.size()) / ITEMS_PER_PAGE))


func _build_dots() -> void:
	for child in _dots.get_children():
		child.queue_free()
	for i in range(_page_count()):
		var dot := Label.new()
		dot.text = "●" if i == _page else "○"
		_dots.add_child(dot)


func _show_page(page: int) -> void:
	page = clampi(page, 0, _page_count() - 1)
	_page = page

	for child in _card_row.get_children():
		_card_row.remove_child(child)
	var start := page * ITEMS_PER_PAGE
	for i in range(start, mini(start + ITEMS_PER_PAGE, _items.size())):
		_card_row.add_child(_items[i])

	_prev_button.disabled = page == 0
	_next_button.disabled = page >= _page_count() - 1
	# The arrow art has no disabled variant, and a TextureButton draws the
	# normal texture at full strength when disabled - so a dead arrow looked
	# exactly like a live one. The "<" and ">" Buttons these replaced greyed
	# themselves out; this puts that feedback back.
	_prev_button.modulate = ARROW_DIM if _prev_button.disabled else Color.WHITE
	_next_button.modulate = ARROW_DIM if _next_button.disabled else Color.WHITE
	for i in range(_dots.get_child_count()):
		_dots.get_child(i).text = "●" if i == page else "○"


# Nothing on screen to update while hidden, and money/coins/level all change
# constantly during play - same guard ShopPanel uses.
func _refresh_items(_unused = null) -> void:
	if not is_visible_in_tree():
		return
	for item in _items:
		item.refresh()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh_items()
		call_deferred("_fit_content")


# See FuelPanel.gd's _fit_content for why this exists - the designed size is a
# guess at actual screen resolution, so shrink to whatever's really there.
func _fit_content() -> void:
	var vbox: Control = $Frame/SafeArea/Margin/VBox
	var safe_area: Control = $Frame/SafeArea
	if not is_instance_valid(vbox) or not is_instance_valid(safe_area):
		return
	vbox.scale = Vector2.ONE
	var natural := vbox.get_combined_minimum_size()
	var available := safe_area.size
	if natural.x <= 0 or natural.y <= 0 or available.x <= 0 or available.y <= 0:
		return
	var s := minf(1.0, minf(available.x / natural.x, available.y / natural.y))
	vbox.scale = Vector2(s, s)
