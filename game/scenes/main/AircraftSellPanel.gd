extends Control

# SELL AN AIRCRAFT, from a card you tapped in the hangar.
#
# This started as a button on the hangar card itself and that was the wrong
# place twice over. The card leaves 26px under the affinity row, and the shop's
# button art is 136x62 with a gradient across BOTH axes - no flat band anywhere,
# so it cannot be nine-sliced - which meant fitting it to a 180px card either
# squashed a pill into a bar or shrank it to 57px and lost the word "Sell".
#
# A panel has room for the button at its own proportions, and room for the thing
# the card could never show: what selling actually costs you. Affinity is 405
# legs of investment at level 10 and the resale does not price it, so the panel
# says so rather than letting the player find out afterwards.

const BOARD := preload("res://assets/board/board_changelist@ipad.png")
const CARD_ART := preload("res://assets/board/board_card1@2x.png")
const TAG_ART := preload("res://assets/board/board_price@2x.png")
const BUTTON_ART := preload("res://assets/buttons/button_red1@2x.png")
const BUTTON_OFF_ART := preload("res://assets/buttons/button_grey3@2x.png")
const CANCEL_ART := preload("res://assets/buttons/button_orange2@2x.png")
const CASH_ICON := preload("res://assets/hud/icon_medium_money1@2x.png")

const BOARD_SIZE := Vector2(679, 325)
const BOARD_SCALE := 0.72

const CARD_PX := Vector2(122.5, 200.0)
const CARD_X := 60.0
const CARD_Y := 84.0
const CARD_ART_RECT := Rect2(0.10, 0.10, 0.80, 0.46)
const CARD_NAME_Y := 0.62
const CARD_OWNED_Y := 0.80

const TITLE_Y := 24.0

# The action column, centred in what is left to the right of the card.
const ACTION_CX := (CARD_X + CARD_PX.x + BOARD_SIZE.x) * 0.5
const TAG_W := 160.0
const TAG_Y := 104.0
# 1x NATIVE. button_red1 is 136x62 and it is @2x art, so its intended display
# size is 68x31 - drawing it at 150 wide was 2.21x that, which is where the rest
# of the game's buttons sit too (UpgradeConfirmPanel 1.88x, DailyLoginPanel
# 2.21x). Both steps use the same width so the button does not change size when
# you press it.
const BUTTON_W := 68.0
const BUTTON_Y := 176.0
const NOTE_Y := 236.0
const CONFIRM_W := BUTTON_W
# 10 PUT CONFIRM AND CANCEL 10px APART, which is inside the slop of a hurried
# click on the one button in the game that destroys an asset. Widened to a
# clear thumb's width - the pair still centres on ACTION_CX, so nothing else
# in the layout moves.
const CONFIRM_GAP := 28.0

const FONT_TITLE := 22
const FONT_NAME := 14
const FONT_OWNED := 12
const FONT_TAG := 17
const FONT_BUTTON := 12
const FONT_NOTE := 11
const FONT_MIN := 9

const COLOR_INK := Color(1.0, 0.96, 0.90)
const COLOR_SUB := Color(0.92, 0.84, 0.70)
const COLOR_WARN := Color(1.0, 0.78, 0.62)

var _model_key := ""
var _confirming := false
var _content: Control


func _ready() -> void:
	visible = false
	custom_minimum_size = BOARD_SIZE
	size = BOARD_SIZE

	var board := TextureRect.new()
	# Before the size, or the art's own dimensions become the minimum.
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.texture = BOARD
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)

	CloseButton.add_to(self, BOARD_SIZE, hide)
	Fleet.fleet_changed.connect(_on_fleet_changed)


func show_for_model(model_key: String) -> void:
	# The hangar is later in the tree and would otherwise cover this - the same
	# reason RoutePickerPanel and UpgradeConfirmPanel both do it.
	move_to_front()
	_model_key = model_key
	_confirming = false
	visible = true
	_rebuild()


func _on_fleet_changed() -> void:
	if not visible:
		return
	# Selling the last one leaves nothing to look at.
	if Fleet.count(_model_key) <= 0:
		hide()
		return
	_rebuild()


func _rebuild() -> void:
	if not visible or _model_key == "":
		return
	# Out of the tree now rather than next frame: selling rebuilds immediately
	# and queue_free is deferred, so the old row would draw over the new one.
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	var title := _label(_fs(FONT_TITLE), COLOR_INK, HORIZONTAL_ALIGNMENT_CENTER)
	title.text = "Sell Aircraft"
	title.position = Vector2(0.0, TITLE_Y)
	title.size = Vector2(BOARD_SIZE.x, 26.0)

	_card()
	_price_tag()
	_button()
	_note()


func _card() -> void:
	var card := TextureRect.new()
	card.texture = CARD_ART
	card.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.stretch_mode = TextureRect.STRETCH_SCALE
	card.position = Vector2(CARD_X, CARD_Y)
	card.size = CARD_PX
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(card)

	# entry_for().get(), not stat(): stat falls back through FALLBACK, which has
	# no "icon" or "name" key and would fault looking for one.
	var entry := ShopCatalog.entry_for(_model_key)
	var icon_path := "res://assets/shop/%s" % str(entry.get("icon", ""))
	if ResourceLoader.exists(icon_path):
		var art := TextureRect.new()
		art.texture = load(icon_path)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		art.custom_minimum_size = Vector2.ZERO
		art.position = Vector2(CARD_X + CARD_PX.x * CARD_ART_RECT.position.x,
			CARD_Y + CARD_PX.y * CARD_ART_RECT.position.y)
		art.size = Vector2(CARD_PX.x * CARD_ART_RECT.size.x,
			CARD_PX.y * CARD_ART_RECT.size.y)
		art.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_content.add_child(art)

	var name_label := _label(FONT_NAME, COLOR_INK, HORIZONTAL_ALIGNMENT_CENTER)
	name_label.text = str(entry.get("name", _model_key))
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.position = Vector2(CARD_X + 6.0, CARD_Y + CARD_PX.y * CARD_NAME_Y)
	name_label.size = Vector2(CARD_PX.x - 12.0, 34.0)

	var owned := _label(FONT_OWNED, COLOR_SUB, HORIZONTAL_ALIGNMENT_CENTER)
	var n := Fleet.count(_model_key)
	owned.text = "%d in the fleet" % n if n != 1 else "1 in the fleet"
	owned.position = Vector2(CARD_X, CARD_Y + CARD_PX.y * CARD_OWNED_Y)
	owned.size = Vector2(CARD_PX.x, 18.0)


func _price_tag() -> void:
	var h: float = TAG_W * TAG_ART.get_height() / float(TAG_ART.get_width())
	var tag := TextureRect.new()
	tag.texture = TAG_ART
	tag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tag.stretch_mode = TextureRect.STRETCH_SCALE
	tag.custom_minimum_size = Vector2.ZERO
	tag.position = Vector2(ACTION_CX - TAG_W * 0.5, TAG_Y)
	tag.size = Vector2(TAG_W, h)
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(tag)

	var icon := TextureRect.new()
	icon.texture = CASH_ICON
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ZERO
	icon.size = Vector2(22.0, 22.0)
	icon.position = Vector2(ACTION_CX - TAG_W * 0.5 + 16.0, TAG_Y + h * 0.5 - 11.0)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(icon)

	var value := _label(FONT_TAG, COLOR_INK, HORIZONTAL_ALIGNMENT_CENTER)
	value.text = "+%s" % FloatingText.grouped(Fleet.sell_value(_model_key))
	value.clip_text = true
	value.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	value.position = Vector2(ACTION_CX - TAG_W * 0.5 + 30.0, TAG_Y)
	value.size = Vector2(TAG_W - 40.0, h)


func _button() -> void:
	var can := Fleet.sellable_count(_model_key) > 0
	if not _confirming:
		_art_button(BUTTON_ART if can else BUTTON_OFF_ART, "Sell",
			ACTION_CX - BUTTON_W * 0.5, BUTTON_W, can, _on_sell_pressed)
		return
	# Confirm step: the destructive one keeps the red, the way out is beside it.
	var x := ACTION_CX - (CONFIRM_W * 2.0 + CONFIRM_GAP) * 0.5
	_art_button(BUTTON_ART, "Confirm", x, CONFIRM_W, true, _on_confirm)
	_art_button(CANCEL_ART, "Cancel", x + CONFIRM_W + CONFIRM_GAP, CONFIRM_W,
		true, _on_cancel)


# One art button, sized from the art's own proportions rather than the box.
func _art_button(art: Texture2D, caption_text: String, x: float, w: float,
		enabled: bool, on_press: Callable) -> void:
	var h: float = w * art.get_height() / float(art.get_width())
	var b := TextureButton.new()
	b.focus_mode = Control.FOCUS_NONE
	# Before the size - the art's 136x62 would otherwise be the minimum.
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_SCALE
	b.texture_normal = art
	b.custom_minimum_size = Vector2.ZERO
	b.size = Vector2(w, h)
	b.position = Vector2(x, BUTTON_Y)
	b.disabled = not enabled
	if enabled:
		b.pressed.connect(on_press)
	_content.add_child(b)

	var caption := _label(FONT_BUTTON,
		Color.WHITE if enabled else Color(0.78, 0.75, 0.72), HORIZONTAL_ALIGNMENT_CENTER)
	caption.text = caption_text
	caption.clip_text = true
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.position = b.position
	caption.size = b.size


func _note() -> void:
	var note := _label(FONT_NOTE, COLOR_SUB, HORIZONTAL_ALIGNMENT_CENTER)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD
	note.position = Vector2(CARD_X + CARD_PX.x + 20.0, NOTE_Y)
	note.size = Vector2(BOARD_SIZE.x - CARD_X - CARD_PX.x - 40.0, 46.0)

	if Fleet.sellable_count(_model_key) <= 0:
		note.text = "Every one of these is flying or waiting at the destination. Bring one home first."
		note.add_theme_color_override("font_color", COLOR_WARN)
		return

	if _confirming:
		note.text = _disclaimer()
		note.add_theme_color_override("font_color", COLOR_WARN)
		return

	note.text = "Half the purchase price. Sells one that is home."


# EVERYTHING SELLING THROWS AWAY, said before it happens rather than after.
# Affinity is 405 legs at level 10 and the resale is a flat half of the
# catalogue price whatever the level, and an aircraft that has landed but not
# been tapped is still holding its flight money.
func _disclaimer() -> String:
	var lost: Array[String] = []
	var level: int = AircraftAffinity.level_for(_model_key)
	if level > 1:
		lost.append("level %d on this airframe" % level)
	if Fleet.unclaimed_count(_model_key) > 0 and Fleet.sellable_count(_model_key) <= Fleet.unclaimed_count(_model_key):
		lost.append("the reward it has not been tapped for")
	if lost.is_empty():
		return "Sell one for $%s? This cannot be undone." % FloatingText.grouped(Fleet.sell_value(_model_key))
	return "You will lose %s. This cannot be undone." % " and ".join(lost)


func _on_sell_pressed() -> void:
	_confirming = true
	_rebuild()


func _on_cancel() -> void:
	_confirming = false
	_rebuild()


func _on_confirm() -> void:
	_confirming = false
	if not Fleet.sell_one(_model_key):
		_rebuild()
		return
	FloatingText.spawn(self, Vector2(ACTION_CX, TAG_Y),
		"+$%s" % FloatingText.grouped(Fleet.sell_value(_model_key)),
		FloatingText.COLOR_GAIN, 0.0)


func _label(size_px: int, color: Color, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l


func _fs(native: int) -> int:
	return maxi(FONT_MIN, roundi(native * BOARD_SCALE))
