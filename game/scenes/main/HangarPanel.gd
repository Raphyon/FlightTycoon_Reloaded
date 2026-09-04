extends PanelContainer

# Fleet roster, grouped by aircraft model (count owned + affinity level). No
# assign/recall here - assigning happens entirely through the apron's own
# panel (see AssignPickerPanel).
#
# Three submenus, picked with the tag-shaped signs down the right edge: all
# aircraft, the idle ones, and the ones currently in use. The split is read
# straight off FleetAircraft.is_idle() (assigned_apron_id == -1) rather than
# tracked separately, so it can't drift out of step with what the aprons
# actually hold.
const HANGAR_TYPE_CARD_SCENE := preload("res://scenes/main/HangarTypeCard.tscn")
const COUNT_BOARD_TEXTURE := preload("res://assets/board/board_airline4@2x.png")

# @2x art is used at its native pixel size throughout this project (see
# button_map1 / board_worldmap in Main.tscn), so nothing here is rescaled -
# each tag button takes its own texture's size, which also keeps the shorter
# "free" tag genuinely shorter instead of padding it to match the others.
const COUNT_BOARD_SIZE := Vector2(410, 62)
const TAB_SEPARATION := 10
# Each tag is captioned underneath, so a cell is taller than its art.
const TAB_LABEL_FONT := 15
const TAB_LABEL_HEIGHT := 22.0
const TAB_RIGHT_MARGIN := 10.0
# The strip sits above centre, not on it. Captioning the tags added ~66px to
# its height, half of which pushed downward into the back arrow's corner - the
# arrow can't move down because the cabin floor is right below it.
const TAB_STRIP_Y_OFFSET := -70.0
const BOARD_RIGHT_MARGIN := 20.0
const BOARD_TOP_MARGIN := 24.0

# TWO ROWS OF FOUR, then a page - matching the aircraft shop, because it is the
# same act (look through a list of aircraft) on the same background. The grid
# was already four wide but unbounded downwards, so a fleet of thirty models
# ran off the bottom of the cabin and out of the panel entirely.
# SIX, THREE WIDE AND TWO TALL, which is what the board has room for at full
# size: 3 x 180 + 2 x 30 = 600 wide and 2 x 210 + 20 = 440 tall, against a
# SafeArea of roughly 1072 x 562. It was eight across four columns - the same
# two rows, so the same height, but 810 wide for no gain, and the page was
# reserving space the roster rarely fills.
const CARDS_PER_PAGE := 6
# HangarTypeCard's own custom_minimum_size, needed here to reserve a full page
# whatever the page actually holds - see _lock_grid_size.
const CARD_SIZE := Vector2(180, 210)
const ARROW_DIM := Color(1, 1, 1, 0.35)

enum Filter { ALL, IDLE, IN_USE }

const TABS := [
	{
		"filter": Filter.ALL, "label": "All Aircraft",
		"normal": "button_planeall@2x.png", "lit": "button_planeall2@2x.png",
	},
	{
		"filter": Filter.IDLE, "label": "Idle Aircraft",
		"normal": "button_planefree@2x.png", "lit": "button_planefree2@2x.png",
	},
	{
		"filter": Filter.IN_USE, "label": "Aircraft In Use",
		"normal": "button_planebussy@2x.png", "lit": "button_planebussy2@2x.png",
	},
]

@onready var _grid: GridContainer = $Frame/SafeArea/Margin/VBox/Grid
@onready var _dots: HBoxContainer = $Frame/SafeArea/Margin/VBox/PageControls/Dots
@onready var _prev_button: TextureButton = $Frame/SafeArea/Margin/VBox/PageControls/PrevButton
@onready var _next_button: TextureButton = $Frame/SafeArea/Margin/VBox/PageControls/NextButton
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton
@onready var _vbox: VBoxContainer = $Frame/SafeArea/Margin/VBox
# Both bits of submenu chrome are anchored by hand, so they hang off Frame
# rather than off this node: HangarPanel is a PanelContainer, and a Container
# overrides its direct children's anchors and offsets to make them fill it -
# which stretched the count board's texture across the whole screen. Frame is
# a plain Control filling the panel, so anchors behave normally inside it.
@onready var _frame: Control = $Frame

var _cards: Dictionary = {}  # model_key -> HangarTypeCard, VISIBLE PAGE ONLY
# Every model in the current submenu, in catalogue order, and how many of each.
# Held across page turns so turning a page does not re-walk the whole fleet.
var _page_keys: Array = []
var _counts: Dictionary = {}
var _page := 0
var _active_filter: int = Filter.ALL
# When set, the hangar is being used as a chooser: it opens on the idle tab and
# every card becomes a button that reports its model back instead of the panel
# being a read-only roster. See open_for_selection.
var _on_pick: Callable = Callable()
var _tab_buttons: Dictionary = {}   # filter -> TextureButton
var _count_label: Label
var _empty_label: Label


func _ready() -> void:
	_close_button.pressed.connect(hide)
	# The reference uses a bottom-right arrow, not a full-width bar.
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	Fleet.fleet_changed.connect(_refresh)
	AircraftAffinity.affinity_changed.connect(_refresh_affinity)
	_lock_grid_size()
	get_tree().root.size_changed.connect(_fit_content)
	_prev_button.pressed.connect(func() -> void: _show_page(_page - 1))
	_next_button.pressed.connect(func() -> void: _show_page(_page + 1))
	_build_count_board()
	_build_empty_label()
	_build_tab_strip()


func _clear_selection_mode() -> void:
	_on_pick = Callable()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh()
		call_deferred("_fit_content")


# THE PANEL MUST NOT RESIZE WHEN THE CONTENTS DO.
#
# _fit_content scales the board to whatever the VBox says it needs, and the
# VBox says less when the grid holds fewer cards - so All, Idle and In use each
# came out at a different size, and so did the last page of a tab whenever it
# was short. Flicking between them made the whole panel breathe.
#
# The grid reserves a FULL PAGE from here on, so its minimum is the same
# whether it is showing eight cards or one, and the scale computed from it does
# not move.
func _lock_grid_size() -> void:
	if not is_instance_valid(_grid):
		return
	var cols: int = maxi(1, _grid.columns)
	var rows: int = ceili(float(CARDS_PER_PAGE) / float(cols))
	var hs: int = _grid.get_theme_constant("h_separation")
	var vs: int = _grid.get_theme_constant("v_separation")
	_grid.custom_minimum_size = Vector2(
		cols * CARD_SIZE.x + (cols - 1) * hs,
		rows * CARD_SIZE.y + (rows - 1) * vs)


# MEASURED A FRAME LATE, ON PURPOSE. Every caller reaches this either through
# call_deferred after rebuilding the roster or straight off root.size_changed -
# in both cases the containers above have been told they changed but have not
# been laid out yet, so SafeArea still reports the rect it had BEFORE. Reading
# it there is how the board came out at 0.57: natural was 543 tall against a
# SafeArea still reporting its base-resolution 311, and the scale computed from
# that pair was applied and then never revisited, because the next call
# measured stale too. One process_frame is all it takes for the anchors to
# resolve, and the numbers this reads are then the ones on screen.
func _fit_content() -> void:
	var vbox: Control = $Frame/SafeArea/Margin/VBox
	var safe_area: Control = $Frame/SafeArea
	if not is_instance_valid(vbox) or not is_instance_valid(safe_area):
		return
	await get_tree().process_frame
	# Both can go away over that frame - the panel closes, the scene changes.
	if not is_instance_valid(vbox) or not is_instance_valid(safe_area):
		return
	# NOT reset to ONE first. scale is a transform, so it feeds neither the
	# VBox's own minimum size nor SafeArea's anchored rect, and resetting it
	# before the guard below meant a measurement that came back unusable left
	# the board at full size rather than at the last scale that worked. That is
	# the other half of what you saw: full size on the first open, because the
	# first measurement always lands before there is a rect to measure.
	var natural := vbox.get_combined_minimum_size()
	var available := safe_area.size
	if natural.x <= 0 or natural.y <= 0 or available.x <= 0 or available.y <= 0:
		return
	var s := minf(1.0, minf(available.x / natural.x, available.y / natural.y))
	vbox.scale = Vector2(s, s)


# --- submenu chrome -----------------------------------------------------

# The tag signs sit directly on the panel rather than inside the content
# VBox: _fit_content() shrinks that VBox to fit the roster, and the signs are
# fixed screen furniture that shouldn't shrink along with it.
func _build_tab_strip() -> void:
	var strip := VBoxContainer.new()
	strip.name = "TabStrip"
	strip.add_theme_constant_override("separation", TAB_SEPARATION)
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.anchor_left = 1.0
	strip.anchor_right = 1.0
	strip.anchor_top = 0.5
	strip.anchor_bottom = 0.5
	strip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	strip.grow_vertical = Control.GROW_DIRECTION_BOTH

	var group := ButtonGroup.new()
	var widest := 0.0
	var total_height := 0.0
	for entry in TABS:
		var normal_texture: Texture2D = load("res://assets/buttons/%s" % entry["normal"])
		var lit_texture: Texture2D = load("res://assets/buttons/%s" % entry["lit"])
		var art_size := normal_texture.get_size()
		widest = maxf(widest, art_size.x)
		total_height += art_size.y + TAB_LABEL_HEIGHT

		var button := TextureButton.new()
		button.texture_normal = normal_texture
		# Godot draws texture_pressed for as long as a toggled button stays on
		# and texture_hover while the mouse is over it, so pointing both at the
		# lit art gives exactly the "clicked or hovering" state the art is for.
		button.texture_hover = lit_texture
		button.texture_pressed = lit_texture
		# The group keeps the three mutually exclusive and, since allow_unpress
		# defaults to false, stops a click on the active tab from leaving no
		# submenu selected at all.
		button.toggle_mode = true
		button.button_group = group
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = art_size
		button.button_pressed = entry["filter"] == _active_filter
		button.pressed.connect(_on_tab_pressed.bind(entry["filter"]))
		_tab_buttons[entry["filter"]] = button
		# The reference art carries no wording, so each tag gets a caption - a
		# handshake, an envelope and a smiley are not self-explanatory, and the
		# hangar's cup and cloud are no better on their own.
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.size_flags_horizontal = Control.SIZE_SHRINK_END
		cell.add_theme_constant_override("separation", 1)
		cell.add_child(button)

		var caption := Label.new()
		caption.text = entry["label"]
		caption.custom_minimum_size = Vector2(art_size.x, 0)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.add_theme_font_size_override("font_size", TAB_LABEL_FONT)
		caption.add_theme_color_override("font_color", Color.WHITE)
		caption.add_theme_color_override("font_outline_color", Color(0.20, 0.09, 0.02, 1))
		caption.add_theme_constant_override("outline_size", 5)
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(caption)
		strip.add_child(cell)

	total_height += TAB_SEPARATION * (TABS.size() - 1)
	strip.offset_left = -(widest + TAB_RIGHT_MARGIN)
	strip.offset_right = -TAB_RIGHT_MARGIN
	strip.offset_top = -total_height * 0.5 + TAB_STRIP_Y_OFFSET
	strip.offset_bottom = total_height * 0.5 + TAB_STRIP_Y_OFFSET
	_frame.add_child(strip)


func _build_count_board() -> void:
	var wrap := Control.new()
	wrap.name = "CountBoard"
	wrap.anchor_left = 1.0
	wrap.anchor_right = 1.0
	wrap.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	wrap.offset_left = -(COUNT_BOARD_SIZE.x + BOARD_RIGHT_MARGIN)
	wrap.offset_right = -BOARD_RIGHT_MARGIN
	wrap.offset_top = BOARD_TOP_MARGIN
	wrap.offset_bottom = BOARD_TOP_MARGIN + COUNT_BOARD_SIZE.y
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var board := TextureRect.new()
	board.texture = COUNT_BOARD_TEXTURE
	board.set_anchors_preset(Control.PRESET_FULL_RECT)
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(board)

	_count_label = Label.new()
	_count_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_count_label.add_theme_font_size_override("font_size", 21)
	_count_label.add_theme_color_override("font_color", Color.WHITE)
	_count_label.add_theme_color_override("font_outline_color", Color(0.11, 0.06, 0.02, 1))
	_count_label.add_theme_constant_override("outline_size", 6)
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.add_child(_count_label)

	_frame.add_child(wrap)


# A submenu with nothing in it is a normal state (no idle aircraft because
# they're all flying, say), so it gets a message rather than a blank slab.
func _build_empty_label() -> void:
	_empty_label = Label.new()
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.add_theme_font_size_override("font_size", 20)
	_empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_empty_label.visible = false
	_vbox.add_child(_empty_label)
	_vbox.move_child(_empty_label, _grid.get_index() + 1)


# Open the hangar to pick an aircraft, rather than to look at one. Forces the
# idle submenu, because those are the only aircraft free to be given a route.
func open_for_selection(on_pick: Callable) -> void:
	_on_pick = on_pick
	_active_filter = Filter.IDLE
	_page = 0
	for f in _tab_buttons:
		_tab_buttons[f].button_pressed = f == Filter.IDLE
	move_to_front()
	show()
	_refresh()


func _on_card_picked(model_key: String) -> void:
	var cb := _on_pick
	_on_pick = Callable()
	hide()
	if cb.is_valid():
		cb.call(model_key)


func _on_tab_pressed(filter: int) -> void:
	if filter == _active_filter:
		return
	_active_filter = filter
	_page = 0
	_refresh()


func _tab_entry(filter: int) -> Dictionary:
	for entry in TABS:
		if entry["filter"] == filter:
			return entry
	return {}


func _aircraft_for_filter() -> Array:
	var subset: Array = []
	# For IDLE keep the idle ones, for IN_USE keep the rest - comparing against
	# the flag directly avoids a second branch that could disagree with it.
	var wants_idle := _active_filter == Filter.IDLE
	for a in Fleet.aircraft:
		if _active_filter == Filter.ALL or a.is_idle() == wants_idle:
			subset.append(a)
	return subset


# --- roster -------------------------------------------------------------

func _refresh(_unused = null) -> void:
	var subset := _aircraft_for_filter()

	_counts = {}
	for a in subset:
		_counts[a.model_key] = _counts.get(a.model_key, 0) + 1

	# CATALOGUE ORDER, not the order aircraft happen to sit in the fleet array.
	# Insertion order was fine while every card was on screen at once; with
	# pages it decides which models share a page, and "whichever you bought
	# first" would reshuffle the whole roster every time you sold something.
	_page_keys = []
	for entry in ShopCatalog.ENTRIES:
		if _counts.has(entry["key"]):
			_page_keys.append(entry["key"])
	# Anything owned that the catalogue no longer lists still gets a card
	# rather than vanishing from your own hangar.
	for model_key in _counts:
		if not _page_keys.has(model_key):
			_page_keys.append(model_key)

	_build_dots()
	_show_page(_page)

	var tab: Dictionary = _tab_entry(_active_filter)
	if _count_label:
		_count_label.text = "%s: %d" % [tab.get("label", "Aircraft"), subset.size()]
	if _empty_label:
		_empty_label.visible = subset.is_empty()
		match _active_filter:
			Filter.IDLE:
				_empty_label.text = "Every aircraft is assigned to an apron."
			Filter.IN_USE:
				_empty_label.text = "No aircraft are assigned to an apron yet."
			_:
				_empty_label.text = "No aircraft yet - buy one in the Aircraft Shop."

	call_deferred("_fit_content")


func _page_count() -> int:
	return maxi(1, ceili(float(_page_keys.size()) / CARDS_PER_PAGE))


func _build_dots() -> void:
	for child in _dots.get_children():
		child.queue_free()
	# One page needs no page indicator - and no arrows either, same rule the
	# livery shop follows.
	#
	# HIDDEN BY GOING TRANSPARENT, NOT BY `visible`. A hidden Control takes no
	# space, so dropping the arrows collapsed their row and the VBox lost 48px -
	# which _fit_content then read as a different natural size and scaled the
	# whole board to. That is the other half of the panel changing size between
	# All, Idle and In use: one of those tabs fits on a single page and the
	# others do not.
	var many := _page_count() > 1
	for arrow in [_prev_button, _next_button]:
		arrow.modulate.a = 1.0 if many else 0.0
		arrow.disabled = not many
		arrow.mouse_filter = (Control.MOUSE_FILTER_STOP if many
			else Control.MOUSE_FILTER_IGNORE)
	if not many:
		return
	for i in range(_page_count()):
		var dot := Label.new()
		dot.text = "\u25cf" if i == _page else "\u25cb"
		_dots.add_child(dot)


func _show_page(page: int) -> void:
	_page = clampi(page, 0, _page_count() - 1)

	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	_cards.clear()

	var start := _page * CARDS_PER_PAGE
	for i in range(start, mini(start + CARDS_PER_PAGE, _page_keys.size())):
		var model_key: String = _page_keys[i]
		var entry := _catalog_entry(model_key)
		var card := HANGAR_TYPE_CARD_SCENE.instantiate()
		_grid.add_child(card)
		var icon_texture: Texture2D = load("res://assets/shop/%s" % entry["icon"]) if entry.size() > 0 else null
		card.setup(model_key, entry.get("name", model_key), icon_texture, _counts[model_key])
		# Only the idle submenu offers a sale - that tab IS "unused aircraft".
		# Selling and choosing are mutually exclusive: while the hangar is a
		# chooser, a card is a thing you pick, not a thing you scrap.
		var choosing := _on_pick.is_valid()
		# Tapping a card opens the sell panel, on every tab except while the
		# hangar is being used to pick an aircraft for a route.
		card.show_details(not choosing, _open_sell_panel)
		card.show_choose(choosing, _on_card_picked)
		_cards[model_key] = card

	_prev_button.disabled = _page == 0
	_next_button.disabled = _page >= _page_count() - 1
	_prev_button.modulate = ARROW_DIM if _prev_button.disabled else Color.WHITE
	_next_button.modulate = ARROW_DIM if _next_button.disabled else Color.WHITE
	for i in range(_dots.get_child_count()):
		_dots.get_child(i).text = "\u25cf" if i == _page else "\u25cb"
	call_deferred("_fit_content")


func _refresh_affinity(_unused = null) -> void:
	for card in _cards.values():
		card.refresh()


func _catalog_entry(model_key: String) -> Dictionary:
	for entry in ShopCatalog.ENTRIES:
		if entry["key"] == model_key:
			return entry
	return {}


func _open_sell_panel(model_key: String) -> void:
	var panel: Control = get_node_or_null("../AircraftSellPanel")
	if panel:
		panel.show_for_model(model_key)
