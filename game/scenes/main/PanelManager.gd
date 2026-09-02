extends Node

# WHO IS ALLOWED TO BE ON SCREEN, and on top of what.
#
# There was no answer to that anywhere. Every panel set its own `visible`, and
# the only thing resembling a rule was Main.VISITING_CLOSED - a hand-written
# list of fifteen names, for one situation, that had to be remembered whenever a
# panel was added. So six interfaces could be open at once (Friends, World Map,
# Daily, Settings, Boosts, Routes), a demolish confirmation could sit alongside
# the upgrade menu it contradicted, and a pad menu could be opened behind a
# build menu with no way to tell which press belonged to which.
#
# IT IS TWO TIERS, NOT ONE. "Only one panel at a time" would be wrong: the skin,
# livery and route pickers are opened BY the pad menu and belong on top of it,
# the upgrade confirmation belongs on top of the building menu, and the assign
# picker on top of the hangar. So:
#
#   BASE     the thing you are looking at. Mutually exclusive - opening one
#            closes every other base AND every dialog, because a dialog belongs
#            to the base that opened it and is meaningless without it.
#   DIALOG   a decision taken ON a base. One at a time, and it leaves the base
#            standing behind it.
#
# NOTHING CALLS THIS. Panels are observed rather than routed through, by
# watching visibility_changed on each one, so all 24 keep using show() and
# `visible = true` exactly as they do now and no call site had to be found and
# rewritten. A manager that needed 24 edits to adopt would have been adopted by
# about 20.
const BASE := [
	"WorldMapPanel", "ShopHubPanel", "ShopPanel", "FuelPanel",
	"ExpansionShopPanel", "PropShopPanel", "HangarPanel", "FriendsPanel",
	"RoutesPanel", "QuestsPanel", "OptionsPanel", "DailyLoginPanel",
	"BoostPanel", "ApronInfoPanel", "BuildingInfoPanel",
]

# NOT MANAGED, and VisitorPanel is why this note exists. It is a HUD readout -
# "who you are visiting", shown only while standing in someone else's airport,
# with its own visibility driven by whether there is anyone to name. Listing it
# as a BASE made every other panel close it, and worse: arriving at a friend's
# airport runs _apply_visiting_ui, which calls close_all(), which hid the panel
# at the exact moment it existed to appear. It was reported as the top-centre
# info panel vanishing.
#
# The test for this list is whether a thing can be DISMISSED. A readout cannot.

# ZoneUnlockPanel is a dialog even though nothing opens it from a base: it is a
# confirmation, and a confirmation that a base could appear on top of would be
# a way to buy a zone by accident.
const DIALOG := [
	"SkinPickerPanel", "LiveryPickerPanel", "RoutePickerPanel",
	"AssignPickerPanel", "UpgradeConfirmPanel", "AircraftSellPanel",
	"FriendInfoPanel", "ZoneUnlockPanel",
]

# FLOATING BUTTONS THAT ARE NOT PART OF A PANEL. They sit over the world, which
# is right, and they sat over open panels too, which is not: a running boost
# parked its button on top of the shop and the routes list. Hidden while a base
# is open and restored to whatever they wanted when it closes - their own logic
# still decides that, this only suppresses it.
const CHROME := ["BoostButton", "QuestsButton"]

var _ui: Node
# Set while we are the ones changing visibility, so hiding six panels does not
# re-enter once per panel and turn one open into a cascade.
var _applying := false


# RETURNS Node, NOT PanelManager, and instantiates by path rather than by name.
# Both deliberate: a self-referential return type, or PanelManager.new() in
# here, needs the class_name global registered - and that only happens after an
# editor rescan, so the script could not be load()ed and exercised from a
# --script harness. The class_name still exists for Main to call attach() by.
static func attach(ui: Node) -> Node:
	var m: Node = load("res://scenes/main/PanelManager.gd").new()
	m.name = "PanelManager"
	m._ui = ui
	ui.add_child(m)
	m._watch()
	return m


func _watch() -> void:
	for panel_name in BASE + DIALOG:
		var node: CanvasItem = _ui.get_node_or_null(panel_name)
		if not node:
			# Not a failure worth stopping for - the lists are written by hand
			# and a renamed panel should say so rather than silently stop being
			# managed, which is how the old hand-written list rotted.
			push_warning("PanelManager: no panel named %s" % panel_name)
			continue
		node.visibility_changed.connect(_on_visibility_changed.bind(node))
	for chrome_name in CHROME:
		var chrome: CanvasItem = _ui.get_node_or_null(chrome_name)
		if not chrome:
			push_warning("PanelManager: no chrome named %s" % chrome_name)
			continue
		chrome.visibility_changed.connect(_on_chrome_changed.bind(chrome))


func _on_visibility_changed(node: CanvasItem) -> void:
	if _applying or not node.visible:
		return
	_applying = true

	var is_base: bool = BASE.has(str(node.name))
	for other_name in (BASE + DIALOG if is_base else DIALOG):
		if other_name == str(node.name):
			continue
		var other: CanvasItem = _ui.get_node_or_null(other_name)
		if other and other.visible:
			other.visible = false

	# THE OPEN PANEL OWNS THE TOP. Z-order was scene order, so a panel could be
	# drawn UNDER chrome it covers - which is why the settings button showed
	# through a shop panel looking pressable while the panel underneath it ate
	# the click. Raised to front, the false affordance goes with it.
	# DEFERRED, because a panel can become visible while its parent is still
	# adding children - move_child() refuses during setup and Godot logs it.
	# End of frame is soon enough for a z-order nobody has seen yet.
	if node is Control:
		node.call_deferred("move_to_front")

	_applying = false
	_sync_chrome()


func _base_open() -> bool:
	for panel_name in BASE:
		var node: CanvasItem = _ui.get_node_or_null(panel_name)
		if node and node.visible:
			return true
	return false


# A chrome node turning ITSELF on while a panel is up - put it back down.
func _on_chrome_changed(node: CanvasItem) -> void:
	if _applying or not node.visible or not _base_open():
		return
	_applying = true
	node.visible = false
	_applying = false


# WE DO NOT REMEMBER WHAT CHROME WANTED, WE ASK IT AGAIN. Remembering was tried
# and is subtly wrong: while the button is forced down, its own logic setting
# `visible = false` changes nothing, fires no signal, and the remembered value
# stays stale - so a boost that expired behind an open shop came back when the
# shop closed. Re-running the button's own _refresh reads real state instead,
# and cannot go stale by construction.
func _sync_chrome() -> void:
	var hide_all := _base_open()
	_applying = true
	for chrome_name in CHROME:
		var node: CanvasItem = _ui.get_node_or_null(chrome_name)
		if not node:
			continue
		if hide_all:
			node.visible = false
		elif node.has_method("_refresh"):
			node.call("_refresh")
	_applying = false


# What is on screen right now, base first. Diagnostic - and the thing to check
# before adding another hand-written list of panel names anywhere.
func open_panels() -> Array[String]:
	var out: Array[String] = []
	for panel_name in BASE + DIALOG:
		var node: CanvasItem = _ui.get_node_or_null(panel_name)
		if node and node.visible:
			out.append(panel_name)
	return out


# Close everything. What Main's visiting switch wanted, without naming fifteen
# panels and forgetting the sixteenth.
func close_all() -> void:
	_applying = true
	for panel_name in BASE + DIALOG:
		var node: CanvasItem = _ui.get_node_or_null(panel_name)
		if node and node.visible:
			node.visible = false
	_applying = false
	_sync_chrome()
