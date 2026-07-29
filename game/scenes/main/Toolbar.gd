extends Control

# The shelf across the bottom of the screen and the buttons sitting on it.
# These used to be squeezed into the top bar at roughly half their native
# size; the art is 109x102 and reads as a physical object resting on a
# ledge, so it lives down here instead.

@onready var _shop_button: TextureButton = $Buttons/ShopButton
@onready var _hangar_button: TextureButton = $Buttons/HangarButton


func _ready() -> void:
	# The map tab lives up under the top-left HUD panel rather than down here,
	# but its wiring belongs with the other HUD buttons.
	var map_tab: TextureButton = get_node("../MapTab")
	var world_map := get_node("../WorldMapPanel")
	map_tab.pressed.connect(func() -> void:
		world_map.visible = not world_map.visible
	)

	var shop_panel := get_node("../ShopHubPanel")
	var hangar_panel := get_node("../HangarPanel")
	_shop_button.pressed.connect(func() -> void:
		shop_panel.visible = not shop_panel.visible
	)
	_hangar_button.pressed.connect(func() -> void:
		hangar_panel.visible = not hangar_panel.visible
	)
	# Keeps each button's pressed texture in sync even when its panel is
	# closed some other way (the panel's own Close button), not just by
	# toggling from here.
	shop_panel.visibility_changed.connect(func() -> void:
		_shop_button.button_pressed = shop_panel.visible
	)
	hangar_panel.visibility_changed.connect(func() -> void:
		_hangar_button.button_pressed = hangar_panel.visible
	)
