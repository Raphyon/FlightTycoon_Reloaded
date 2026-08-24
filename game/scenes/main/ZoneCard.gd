extends Control

const DISABLED_MODULATE := Color(0.6, 0.6, 0.6, 1.0)
const PRESSED_TEXTURE := preload("res://assets/buttons/button_grey3@2x.png")
const PRESSED_FLASH_TIME := 0.2

var _entry: Dictionary
var _unlock_button: TextureButton
var _state_label: Label
var _normal_texture: Texture2D


func setup(entry: Dictionary) -> void:
	_entry = entry

	var background: TextureRect = $Background
	var lock_overlay: Control = $Background/LockOverlay
	var level_label: Label = $LevelTag/LevelLabel
	var price_label: Label = $PriceTag/PriceLabel
	_unlock_button = $UnlockWrap/UnlockButton
	_state_label = $UnlockWrap/StateLabel

	background.texture = load("res://assets/board/%s" % entry["card"])
	lock_overlay.visible = not entry["implemented"]
	_normal_texture = _unlock_button.texture_normal
	_unlock_button.pressed.connect(_on_unlock_pressed)

	if entry["implemented"]:
		var req: Dictionary = ZoneProgress.requirement_for(entry["key"])
		level_label.text = "Lvl %d" % req.get("level", 1)
		if req.has("cost"):
			price_label.text = "%d" % req["cost"]
		else:
			price_label.text = "Free"
	else:
		level_label.text = "-"
		price_label.text = "-"

	refresh()


func _on_unlock_pressed() -> void:
	ZoneProgress.unlock(_entry["key"])
	_flash_button()


func _flash_button() -> void:
	_unlock_button.texture_normal = PRESSED_TEXTURE
	await get_tree().create_timer(PRESSED_FLASH_TIME).timeout
	if is_instance_valid(_unlock_button):
		_unlock_button.texture_normal = _normal_texture


func refresh() -> void:
	var key: String = _entry["key"]
	if not _entry["implemented"]:
		_unlock_button.disabled = true
		_state_label.text = "Soon"
	elif ZoneProgress.is_unlocked(key):
		_unlock_button.disabled = true
		_state_label.text = "Unlocked"
	else:
		var req: Dictionary = ZoneProgress.requirement_for(key)
		if Progression.level < req.level:
			_unlock_button.disabled = true
			_state_label.text = "Locked"
		elif Economy.money < req.cost:
			_unlock_button.disabled = true
			_state_label.text = "Can't afford"
		else:
			_unlock_button.disabled = false
			_state_label.text = "Unlock"
	_unlock_button.modulate = DISABLED_MODULATE if _unlock_button.disabled else Color.WHITE
