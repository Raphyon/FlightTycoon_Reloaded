extends Node2D


var _panels: Node


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
	# One place that knows what may be on screen at once - see PanelManager.
	# Attached before anything can open a panel, and it observes rather than
	# being called, so no panel had to change to be governed by it.
	# Loaded by PATH, not by class_name. A class_name global only registers
	# after an editor rescan, so a fresh checkout parses Main before the global
	# exists and dies with "Identifier PanelManager not declared" - which is a
	# clone that does not boot, for a convenience worth nothing here.
	_panels = load("res://scenes/main/PanelManager.gd").attach($UI)
	Maps.map_changed.connect(_on_map_changed)
	DebugState.flags_changed.connect(_apply_ui_visibility)
	_apply_map()
	_apply_visiting_ui()
	$Camera2D.position = $ApronLayer.get_occupied_position()
	_offer_daily_login()
	if OS.get_cmdline_user_args().has("--dump-ui"):
		call_deferred("_dump_ui")


# WHERE THINGS ACTUALLY ARE, because reading a layout off the source is how you
# ship a panel three times and get it wrong three times. Containers decide the
# real rectangles - a VBox stretches its children, a negative separation draws
# one on top of another, a margin moves a whole block - and none of that is
# visible in the code that sets it up.
#
#     godot --headless --path game -- --dump-ui
#
# Prints every child of a panel with its global rect, so overlaps and
# misalignments are arithmetic rather than opinion.
func _dump_ui() -> void:
	for _i in range(3):
		await get_tree().process_frame
	for panel_name in ["ShopHubPanel", "FuelPanel", "HangarPanel", "RoutesPanel"]:
		var panel: Control = $UI.get_node_or_null(panel_name)
		if panel == null:
			continue
		panel.visible = true
		for _i in range(3):
			await get_tree().process_frame
		print("UI %s %s" % [panel_name, panel.get_global_rect()])
		_dump_children(panel, 1)
		panel.visible = false
	get_tree().quit()


func _dump_children(node: Node, depth: int) -> void:
	if depth > 4:
		return
	for child in node.get_children():
		if child is Control:
			var c := child as Control
			# The texture too, where there is one - so a dump can be composited
			# back into a picture with the real art at the real rectangles.
			var tex := ""
			if c is TextureRect and (c as TextureRect).texture:
				tex = (c as TextureRect).texture.resource_path
			elif c is TextureButton and (c as TextureButton).texture_normal:
				tex = (c as TextureButton).texture_normal.resource_path
			elif c is Label:
				tex = "TEXT:" + (c as Label).text.replace("\n", "\\n")
			print("UI %s%s %s %s %s" % ["  ".repeat(depth), c.name,
				c.get_global_rect(), c.get_class(), tex])
			_dump_children(child, depth + 1)


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
# RoutesPanel is NOT in here. Your routes keep running while you are away, so
# being unable to look at them was the one thing you might genuinely want from
# someone else's airport - and its actions are fleet-level rather than
# map-level, so collecting a landed aircraft from here works as it does at home.
const VISITING_CLOSED := ["WorldMapPanel", "ShopHubPanel", "HangarPanel", "FriendsPanel", "FriendInfoPanel", "ShopPanel",
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
	# Everything except RoutesPanel, which is deliberately left running - see
	# the note on VISITING_CLOSED above. close_all() then reopening it is
	# simpler than maintaining a list that has to be edited whenever a panel is
	# added, which is exactly how the old list fell behind.
	var routes: CanvasItem = $UI.get_node_or_null("RoutesPanel")
	var routes_open: bool = routes != null and routes.visible
	_panels.close_all()
	if routes_open and routes:
		routes.visible = true


# DebugState.hide_ui - everything on the UI layer goes except the debug menu,
# which is the only way to turn it back on. Hiding the CanvasLayer itself would
# take the menu with it and leave no route out but restarting.
#
# MODULATE, NOT visible. Panels open and close themselves constantly, so their
# visible flag is theirs - overwriting it would reopen every closed panel the
# moment the toggle came back off. Alpha takes them off the screen without
# touching what they think they are doing.
#
# Input has to go with the pixels, or an invisible toolbar still swallows clicks
# meant for the airport behind it. The previous mouse_filter is kept per node
# rather than assumed, because they are not all the same.
var _ui_mouse_filters := {}


func _apply_ui_visibility() -> void:
	var hide: bool = DebugState.hide_ui
	for child in $UI.get_children():
		if child.name == "DebugMenu" or not child is CanvasItem:
			continue
		(child as CanvasItem).modulate.a = 0.0 if hide else 1.0
		if not child is Control:
			continue
		var control := child as Control
		if hide:
			if not _ui_mouse_filters.has(control):
				_ui_mouse_filters[control] = control.mouse_filter
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif _ui_mouse_filters.has(control):
			control.mouse_filter = _ui_mouse_filters[control]
			_ui_mouse_filters.erase(control)
