extends Node2D


func _ready() -> void:
	print("ft-proto booted")
	# Aprons and world aircraft (including the starting plane) are all
	# spawned by ApronLayer.gd, driven by Fleet's assignment data - see
	# AreaOrigins for the markers and data/apron_layout.json for the cells.
	Maps.map_changed.connect(_on_map_changed)
	_apply_map()
	_apply_visiting_ui()
	$Camera2D.position = $ApronLayer.get_occupied_position()


# Travelling swaps the whole world: each airport is its own background at its
# own size, with its own aprons, clouds and traced paths. See Maps.
func _on_map_changed(_map_key: String) -> void:
	_apply_map()
	_apply_visiting_ui()
	# Both editors key everything off the current map, so they have to rebuild
	# rather than keep showing the airport we just left. Deferred because a
	# rebuild frees the existing slot nodes.
	$ApronLayer.call_deferred("reload_for_map")
	$CloudLayer.call_deferred("reload_for_map")
	$PathLayer.call_deferred("reload_for_map")
	# Nothing is guaranteed to be occupied on a map you've never built on, so
	# fall back to the middle of the new world rather than leaving the camera
	# parked over wherever the last airport's aircraft was.
	call_deferred("_recentre_camera")


func _apply_map() -> void:
	$Background.texture = load(Maps.background_for())
	# The camera clamps to the world's edges, so its limits are per-map - left
	# at homeland's 3072x2304, a smaller airport would pan off into blank space.
	var size := Maps.size_for()
	var camera: Camera2D = $Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = size.x
	camera.limit_bottom = size.y


func _recentre_camera() -> void:
	var occupied: Vector2 = $ApronLayer.get_occupied_position()
	$Camera2D.position = occupied if occupied != Vector2.ZERO else Vector2(Maps.size_for()) * 0.5


# Someone else's airport is a place you visit, not one you run: there's no
# money to spend, nothing to build, no fleet to manage and no other world to
# travel to from here. So the whole player HUD goes away and the only things
# left are the visitor panel, the pads holding your aircraft, and the way home.
#
# Lives here rather than in Toolbar because it spans most of the HUD, and
# because Main is what already knows the map changed.
# The toolbar shelf is NOT in here: it carries the Home button now, so it has
# to stay. Which of its buttons are available is the toolbar's own business -
# see Toolbar._apply_map.
const VISITING_HIDDEN := ["TopBarRight", "TopBarLeft", "TopBar", "MapTab"]
# Panels that must not be left open behind us when we arrive.
const VISITING_CLOSED := ["WorldMapPanel", "ShopHubPanel", "HangarPanel", "FriendsPanel", "FriendInfoPanel", "RoutesPanel", "ShopPanel",
	"FuelPanel", "ExpansionShopPanel", "ApronInfoPanel", "SkinPickerPanel",
	"AssignPickerPanel", "BuildingInfoPanel"]


func _apply_visiting_ui() -> void:
	var visiting := Maps.is_robot_map()
	for node_name in VISITING_HIDDEN:
		var node: CanvasItem = $UI.get_node_or_null(node_name)
		if node:
			node.visible = not visiting
	if not visiting:
		return
	for node_name in VISITING_CLOSED:
		var node: CanvasItem = $UI.get_node_or_null(node_name)
		if node:
			node.visible = false
