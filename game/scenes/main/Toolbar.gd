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
	var friends_panel := get_node("../FriendsPanel")
	var routes_panel := get_node("../RoutesPanel")
	var routes_button: TextureButton = get_node("Buttons/RoutesButton")
	routes_button.pressed.connect(func() -> void:
		routes_panel.visible = not routes_panel.visible
	)
	routes_panel.visibility_changed.connect(func() -> void:
		routes_button.button_pressed = routes_panel.visible
	)
	var friends_button: TextureButton = get_node("Buttons/FriendsButton")
	friends_button.pressed.connect(func() -> void:
		friends_panel.visible = not friends_panel.visible
	)
	friends_panel.visibility_changed.connect(func() -> void:
		friends_button.button_pressed = friends_panel.visible
	)
	_shop_button.pressed.connect(func() -> void:
		shop_panel.visible = not shop_panel.visible
	)
	_hangar_button.pressed.connect(func() -> void:
		hangar_panel.visible = not hangar_panel.visible
	)
	# Shop and Hangar are things you do at your own airport; visiting someone
	# else's leaves just the way home on the shelf. The Home button hides
	# itself the other way round - see HomeButton.gd.

	Maps.map_changed.connect(func(_k: String) -> void: _apply_map())
	_apply_map()

	# Keeps each button's pressed texture in sync even when its panel is
	# closed some other way (the panel's own Close button), not just by
	# toggling from here.
	shop_panel.visibility_changed.connect(func() -> void:
		_shop_button.button_pressed = shop_panel.visible
	)
	hangar_panel.visibility_changed.connect(func() -> void:
		_hangar_button.button_pressed = hangar_panel.visible
	)


func _apply_map() -> void:
	var visiting := Maps.is_robot_map()
	_shop_button.visible = not visiting
	_hangar_button.visible = not visiting
	get_node("Buttons/FriendsButton").visible = not visiting
	# ROUTES STAYS. It is the one panel worth reaching from someone else's
	# airport: the fleet keeps flying while you are here, and without it a
	# landing at home is invisible until you travel back.
	get_node("Buttons/RoutesButton").visible = true

