extends PanelContainer

const SHOP_ITEM_SCENE := preload("res://scenes/main/ShopItem.tscn")
const ITEMS_PER_PAGE := 4

@onready var _card_row: HBoxContainer = $Frame/SafeArea/Margin/VBox/CardRow
@onready var _dots: HBoxContainer = $Frame/SafeArea/Margin/VBox/PageControls/Dots
const ARROW_DIM := Color(1, 1, 1, 0.35)

@onready var _prev_button: TextureButton = $Frame/SafeArea/Margin/VBox/PageControls/PrevButton
@onready var _next_button: TextureButton = $Frame/SafeArea/Margin/VBox/PageControls/NextButton
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton

var _items: Array = []
var _page := 0


func _ready() -> void:
	_close_button.pressed.connect(hide)
	# The reference uses a bottom-right arrow, not a full-width bar.
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	_prev_button.pressed.connect(func() -> void: _show_page(_page - 1))
	_next_button.pressed.connect(func() -> void: _show_page(_page + 1))
	Fleet.fleet_changed.connect(_refresh_items)
	Economy.money_changed.connect(_refresh_items)
	# The Ark and the UFO are priced in coins, so a coin balance change is just
	# as much a reason to re-evaluate what's affordable as a cash one.
	Coins.coins_changed.connect(_refresh_items)
	# Levelling up unlocks aircraft, so it changes what's buyable too.
	Progression.level_changed.connect(_refresh_items)

	for entry in ShopCatalog.ENTRIES:
		var item := SHOP_ITEM_SCENE.instantiate()
		item.setup(entry)
		_items.append(item)

	_build_dots()
	_show_page(0)

	get_tree().root.size_changed.connect(_fit_content)
	call_deferred("_fit_content")


# See FuelPanel.gd's _fit_content for why this exists - the designed size is
# a guess at actual screen resolution, so shrink to whatever's really there.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		call_deferred("_fit_content")
		# Catch up on everything skipped while hidden - see _refresh_items.
		_refresh_items()


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


func _page_count() -> int:
	return ceili(float(_items.size()) / ITEMS_PER_PAGE)


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


# Money, coins, level and the fleet all change constantly while the shop is
# shut, and each one used to re-evaluate every card. That was 14 cards; the
# hand-made fleet took it to 29, and with a full apron of aircraft landing it
# runs on nearly every frame. Nothing is on screen to update, so don't - the
# visibility notification above refreshes on the way back in.
func _refresh_items(_unused = null) -> void:
	# In-tree, not the local flag: a shown panel under a hidden parent is still
	# off screen, and the notification fires again when the parent comes back.
	if not is_visible_in_tree():
		return
	for item in _items:
		item.refresh()
