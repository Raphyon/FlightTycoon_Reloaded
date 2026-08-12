extends VBoxContainer

signal buy_pressed

const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 1.0)
const PRESSED_TEXTURE := preload("res://assets/buttons/button_grey3@2x.png")
const PRESSED_FLASH_TIME := 0.2
const NOTE_FONT_SIZE := 22
const NOTE_PREMIUM := Color(1.0, 0.55, 0.45)
const NOTE_DISCOUNT := Color(0.55, 1.0, 0.6)

@onready var _tag_wrap: Control = $TagWrap
@onready var _price_icon: TextureRect = $TagWrap/PriceIcon
@onready var _price_label: Label = $TagWrap/PriceLabel
@onready var _lock_overlay: Control = $IconWrap/LockOverlay
@onready var _qty_label: Label = $QtyLabel
@onready var _buy_button: TextureButton = $BuyWrap/BuyButton

var _normal_texture: Texture2D
var _note_label: Label


func setup(qty: int, price_icon_texture: Texture2D, locked: bool) -> void:
	_price_icon.texture = price_icon_texture
	_qty_label.text = "+%d fuel" % qty
	_lock_overlay.visible = locked
	_buy_button.disabled = locked
	_normal_texture = _buy_button.texture_normal
	if locked:
		_tag_wrap.modulate = DISABLED_MODULATE
		_qty_label.modulate = DISABLED_MODULATE
		_buy_button.modulate = DISABLED_MODULATE
	else:
		_buy_button.pressed.connect(_on_buy_pressed)


func _on_buy_pressed() -> void:
	buy_pressed.emit()
	_flash_button()


func _flash_button() -> void:
	_buy_button.texture_normal = PRESSED_TEXTURE
	await get_tree().create_timer(PRESSED_FLASH_TIME).timeout
	if is_instance_valid(_buy_button):
		_buy_button.texture_normal = _normal_texture


func set_price_text(text: String) -> void:
	_price_label.text = text


# The batch's premium or discount against the market price - "+20%", "-10%",
# blank at par. Built in code rather than added to FuelOption.tscn because the
# four cells are baked instances of that scene (see FuelPanel), so a node added
# there has to be added four times and kept in step; here it arrives with the
# text or not at all.
func set_note_text(text: String) -> void:
	if text == "" and _note_label == null:
		return
	if _note_label == null:
		_note_label = Label.new()
		_note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_note_label.add_theme_font_size_override("font_size", NOTE_FONT_SIZE)
		_note_label.add_theme_color_override("font_outline_color", Color(0.08, 0.06, 0.03))
		_note_label.add_theme_constant_override("outline_size", 4)
		_note_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_note_label)
		# Directly under the quantity, so it reads as part of "+50 fuel" rather
		# than as a note on the buy button.
		move_child(_note_label, _qty_label.get_index() + 1)
	_note_label.text = text
	_note_label.visible = text != ""
	_note_label.add_theme_color_override("font_color",
		NOTE_DISCOUNT if text.begins_with("-") else NOTE_PREMIUM)


func set_affordable(can_afford: bool) -> void:
	_buy_button.disabled = not can_afford
	_buy_button.modulate = Color.WHITE if can_afford else DISABLED_MODULATE
