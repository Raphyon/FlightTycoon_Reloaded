extends VBoxContainer

signal buy_pressed

const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 1.0)
const PRESSED_TEXTURE := preload("res://assets/buttons/button_grey3@2x.png")
const PRESSED_FLASH_TIME := 0.2

@onready var _tag_wrap: Control = $TagWrap
@onready var _price_icon: TextureRect = $TagWrap/PriceIcon
@onready var _price_label: Label = $TagWrap/PriceLabel
@onready var _lock_overlay: Control = $IconWrap/LockOverlay
@onready var _qty_label: Label = $QtyLabel
@onready var _buy_button: TextureButton = $BuyWrap/BuyButton

var _normal_texture: Texture2D


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


func set_affordable(can_afford: bool) -> void:
	_buy_button.disabled = not can_afford
	_buy_button.modulate = Color.WHITE if can_afford else DISABLED_MODULATE
