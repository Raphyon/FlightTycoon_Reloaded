extends PanelContainer

# Friends list, and the way to visit one. Same shape as HangarPanel: tag-shaped
# signs down the right edge switch between three submenus, and a count board
# sits top-right.
#
# The list isn't a separate table - a friend IS a visitable airport, so it's
# read off Maps (any map carrying a "visiting" entry). That keeps a friend's
# name, level, avatar and distance in exactly one place, which is also what the
# visitor panel reads when you're standing in their world.
#
# Only the friends tab has anything in it. Guests has no defined meaning yet
# and invites needs a system that doesn't exist, so both show what they'd hold
# rather than pretending to be empty lists.
const COUNT_BOARD_TEXTURE := preload("res://assets/board/board_airline4@2x.png")

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

enum Tab { FRIENDS, REQUESTS, CROWDS }

const TABS := [
	{
		"tab": Tab.FRIENDS, "label": "Friends",
		"normal": "button_friend1@2x.png", "lit": "button_friend2@2x.png",
	},
	{
		"tab": Tab.REQUESTS, "label": "Requests",
		"normal": "button_friendinvite1@2x.png", "lit": "button_friendinvite2@2x.png",
	},
	{
		"tab": Tab.CROWDS, "label": "Crowds",
		"normal": "button_friendguest@2x.png", "lit": "button_friendguest2@2x.png",
	},
]

@onready var _grid: GridContainer = $Frame/SafeArea/Margin/VBox/Grid
@onready var _close_button: Button = $Frame/SafeArea/Margin/VBox/CloseButton
@onready var _vbox: VBoxContainer = $Frame/SafeArea/Margin/VBox
# Anchored chrome hangs off Frame, not off this node: PanelContainer overrides
# its direct children's anchors to make them fill it.
@onready var _frame: Control = $Frame

var _active_tab: int = Tab.FRIENDS
var _count_label: Label
var _empty_label: Label


func _ready() -> void:
	_close_button.pressed.connect(hide)
	# The reference uses a bottom-right arrow, not a full-width bar.
	_close_button.visible = false
	BackButton.add_to($Frame, hide)
	get_tree().root.size_changed.connect(_fit_content)
	Friends.friends_changed.connect(func() -> void:
		if visible:
			_refresh()
	)
	_build_count_board()
	_build_empty_label()
	_build_tab_strip()


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and visible:
		_refresh()
		call_deferred("_fit_content")


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


# --- chrome --------------------------------------------------------------

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
		# hover and pressed both lit: a toggled button keeps drawing
		# texture_pressed, which is exactly the "current tab" state.
		button.texture_hover = lit_texture
		button.texture_pressed = lit_texture
		button.toggle_mode = true
		button.button_group = group
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.custom_minimum_size = art_size
		button.button_pressed = entry["tab"] == _active_tab
		button.pressed.connect(_on_tab_pressed.bind(entry["tab"]))
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


func _build_empty_label() -> void:
	_empty_label = Label.new()
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_empty_label.custom_minimum_size = Vector2(520, 0)
	_empty_label.add_theme_font_size_override("font_size", 20)
	_empty_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.75))
	_empty_label.visible = false
	_vbox.add_child(_empty_label)
	_vbox.move_child(_empty_label, _grid.get_index() + 1)


func _on_tab_pressed(tab: int) -> void:
	if tab == _active_tab:
		return
	_active_tab = tab
	_refresh()


func _tab_entry(tab: int) -> Dictionary:
	for entry in TABS:
		if entry["tab"] == tab:
			return entry
	return {}


# --- list ----------------------------------------------------------------

func _refresh() -> void:
	for child in _grid.get_children():
		child.queue_free()

	var keys: Array = Friends.list() if _active_tab == Tab.FRIENDS else []
	for map_key in keys:
		_grid.add_child(_build_card(map_key))

	var tab: Dictionary = _tab_entry(_active_tab)
	if _count_label:
		_count_label.text = "%s: %d" % [tab.get("label", ""), keys.size()]
	if _empty_label:
		_empty_label.visible = keys.is_empty()
		match _active_tab:
			Tab.CROWDS:
				_empty_label.text = "No crowds right now."
			Tab.REQUESTS:
				_empty_label.text = "No friend requests."
			_:
				_empty_label.text = "No friends yet."
	call_deferred("_fit_content")


# Each entry is one of the blue cards, wrapped in a button so clicking it opens
# the info popup (visit / remove) rather than travelling straight away.
func _build_card(map_key: String) -> Control:
	var button := TextureButton.new()
	button.texture_normal = FriendCard.back_for(map_key)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.custom_minimum_size = FriendCard.SIZE
	button.pressed.connect(_on_card_pressed.bind(map_key))
	# Contents only - the button itself is already drawing the card back.
	FriendCard.populate(button, map_key, Rect2(Vector2.ZERO, FriendCard.SIZE))
	return button


func _on_card_pressed(map_key: String) -> void:
	get_node("../FriendInfoPanel").show_friend(map_key)
