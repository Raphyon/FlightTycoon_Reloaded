extends Node2D


func _ready() -> void:
	print("ft-proto booted")
	# The shop shows ENTRIES in array order, so an entry in the wrong slot is a
	# silent bug - see ShopCatalog.order_problems. Shouted at boot rather than
	# left for somebody to spot the prices going backwards.
	for problem in ShopCatalog.order_problems():
		push_warning("shop order: %s" % problem)
	# Aprons and world aircraft (including the starting plane) are all
	# spawned by ApronLayer.gd, driven by Fleet's assignment data - see
	# AreaOrigins for the markers and data/apron_layout.json for the cells.
	Maps.map_changed.connect(_on_map_changed)
	_apply_map()
	_apply_visiting_ui()
	$Camera2D.position = $ApronLayer.get_occupied_position()
	_offer_daily_login()


# A daily that you have to go looking for is not a daily. It opens itself when a
# day is owed, which is the whole mechanism - the reward is the excuse, coming
# back is the point.
#
# Deferred a frame: SaveGame loads on its own _ready, and asking before that has
# run reads a streak of zero on every launch and hands out day 1 forever.
func _offer_daily_login() -> void:
	await get_tree().process_frame
	if Maps.is_robot_map():
		return
	if not DailyLogin.can_claim():
		return
	var panel: Control = $UI.get_node_or_null("DailyLoginPanel")
	if panel:
		panel.show_panel()


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
	# THE VIEW CARRIES OVER. Travelling used to recentre, which meant sending an
	# aircraft to a friend and then having to find the same corner of the map
	# again by hand - and the robot airports borrow homeland's apron layout, so
	# the coordinates line up and the pad you were looking at is in the same
	# place on the other side.
	call_deferred("_carry_camera_over", $Camera2D.position)


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


# Keeps the view where it was, pulled inside the new world's bounds. A map that
# is smaller than the one just left would otherwise leave the camera parked off
# the edge of it.
func _carry_camera_over(previous: Vector2) -> void:
	var size := Vector2(Maps.size_for())
	var camera: Camera2D = $Camera2D
	var half := camera.get_viewport_rect().size * 0.5 / maxf(camera.zoom.x, 0.001)
	camera.position = Vector2(
		clampf(previous.x, minf(half.x, size.x * 0.5), maxf(size.x - half.x, size.x * 0.5)),
		clampf(previous.y, minf(half.y, size.y * 0.5), maxf(size.y - half.y, size.y * 0.5)))


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
	"AssignPickerPanel", "BuildingInfoPanel", "UpgradeConfirmPanel",
	"DailyLoginPanel", "BoostPanel"]


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
