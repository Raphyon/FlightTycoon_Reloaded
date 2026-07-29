extends Control

const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 1.0)
const PRESSED_TEXTURE := preload("res://assets/buttons/button_grey3@2x.png")
const PRESSED_FLASH_TIME := 0.2

var _entry: Dictionary
var _buy_button: TextureButton
var _state_label: Label
var _normal_texture: Texture2D


func setup(entry: Dictionary) -> void:
	_entry = entry

	var name_label: Label = $NameLabel
	var icon: TextureRect = $IconWrap/Icon
	var lock_overlay: Control = $IconWrap/LockOverlay
	var price_label: Label = $PriceTag/PriceLabel
	_buy_button = $BuyWrap/BuyButton
	_state_label = $BuyWrap/StateLabel

	name_label.text = entry["name"]
	icon.texture = load("res://assets/shop/%s" % entry["icon"])
	lock_overlay.visible = not entry.get("has_world_sprite", false)
	price_label.text = "%d" % entry["price"]
	_normal_texture = _buy_button.texture_normal
	_buy_button.pressed.connect(_on_buy_pressed)
	refresh()


func _on_buy_pressed() -> void:
	Fleet.buy(_entry["key"], _entry["price"])
	_flash_button()


func _flash_button() -> void:
	_buy_button.texture_normal = PRESSED_TEXTURE
	await get_tree().create_timer(PRESSED_FLASH_TIME).timeout
	if is_instance_valid(_buy_button):
		_buy_button.texture_normal = _normal_texture


func refresh() -> void:
	if not _entry.get("has_world_sprite", false):
		_buy_button.disabled = true
		_state_label.text = "No art yet"
	elif Economy.money < _entry["price"]:
		_buy_button.disabled = true
		_state_label.text = "Can't afford"
	else:
		_buy_button.disabled = false
		_state_label.text = "Buy"
	_buy_button.modulate = DISABLED_MODULATE if _buy_button.disabled else Color.WHITE
