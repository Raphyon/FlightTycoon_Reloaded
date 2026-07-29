extends PanelContainer

@onready var _title: Label = $Margin/VBox/TitleLabel
@onready var _slots_row: Control = $Margin/VBox/SlotsRow
@onready var _skin_column: Control = $Margin/VBox/SlotsRow/SkinColumn
@onready var _plane_column: Control = $Margin/VBox/SlotsRow/PlaneColumn
@onready var _skin_preview: TextureRect = $Margin/VBox/SlotsRow/SkinColumn/SkinSlot/SkinPreview
@onready var _skin_empty_label: Label = $Margin/VBox/SlotsRow/SkinColumn/SkinSlot/SkinEmptyLabel
@onready var _skin_bonus_label: Label = $Margin/VBox/SlotsRow/SkinColumn/SkinBonusLabel
@onready var _skin_button: Button = $Margin/VBox/SlotsRow/SkinColumn/SkinButton
@onready var _plane_icon: TextureRect = $Margin/VBox/SlotsRow/PlaneColumn/PlaneSlot/PlaneIcon
@onready var _plane_empty_label: Label = $Margin/VBox/SlotsRow/PlaneColumn/PlaneSlot/PlaneEmptyLabel
@onready var _plane_button: Button = $Margin/VBox/SlotsRow/PlaneColumn/PlaneButton
@onready var _status: Label = $Margin/VBox/SlotsRow/StatusColumn/StatusLabel
@onready var _action_button: Button = $Margin/VBox/SlotsRow/StatusColumn/ActionButton
@onready var _close_button: Button = $Margin/VBox/CloseButton

var _apron_id: int = -1
var _apron: Apron


func _ready() -> void:
	_close_button.pressed.connect(hide)
	_action_button.pressed.connect(_on_action_pressed)
	_plane_button.pressed.connect(_on_plane_button_pressed)
	_skin_button.pressed.connect(_on_skin_button_pressed)
	Fleet.fleet_changed.connect(_refresh)
	ApronProgress.built_changed.connect(_refresh)
	ApronSkins.skin_changed.connect(_refresh)


func _process(_delta: float) -> void:
	if visible:
		_refresh()


func show_apron(apron: Apron) -> void:
	_apron_id = apron.id
	_apron = apron
	_title.text = "Apron %d" % apron.id
	show()
	_refresh()


func _refresh() -> void:
	if not visible or _apron_id == -1:
		return
	# _apron.built was correct as of show_apron() and stays valid if it was
	# already true then (built/free-by-default never reverts) - but it won't
	# pick up a build that happens *while this panel is open*, so OR it with
	# a live check too.
	if not (_apron and (_apron.built or ApronProgress.is_built(_apron_id))):
		var cost := ApronProgress.cost_for_area(_apron.area_name)
		# Only the skin/plane slots don't apply before it's built - the
		# StatusColumn (with the Build button) is a sibling inside the same
		# row, so hiding the whole row hid the Build button too.
		_slots_row.visible = true
		_skin_column.visible = false
		_plane_column.visible = false
		# A locked zone is bought whole in the expansion shop, so there's no
		# per-apron action to offer here at all.
		if not ZoneProgress.is_unlocked(_apron.area_name):
			_status.text = "%s is locked - unlock it in the Expansion Shop" % _apron.area_name
			_action_button.visible = false
			return
		_status.text = "Not built yet"
		_action_button.visible = true
		_action_button.text = "Build ($%d)" % cost
		_action_button.disabled = Economy.money < cost
		return
	_slots_row.visible = true
	_skin_column.visible = true
	_plane_column.visible = true
	_refresh_skin_slot()

	var a := Fleet.get_aircraft_at_apron(_apron_id)
	_refresh_plane_slot(a)

	if not a:
		_status.text = "Free"
		_action_button.visible = false
		return

	_action_button.visible = true
	_action_button.disabled = false
	match a.state:
		FleetAircraft.State.PARKED:
			_status.text = "Parked - needs %d fuel" % Fleet.FUEL_PER_TRIP
			_action_button.text = "Fuel & Depart (%s)" % Fleet.DESTINATION_NAME
			_action_button.disabled = FuelStore.amount < Fleet.FUEL_PER_TRIP
		FleetAircraft.State.FLYING_OUT:
			_status.text = "Flying to %s - %ds left" % [Fleet.DESTINATION_NAME, ceili(a.flight_time_left)]
			_action_button.visible = false
		FleetAircraft.State.AWAITING_DEST_CLAIM:
			_status.text = "Arrived at %s" % Fleet.DESTINATION_NAME
			_action_button.text = "Claim $%d" % Fleet.REWARD_AT_DESTINATION
		FleetAircraft.State.AWAITING_DEST_REFUEL:
			_status.text = "Reward claimed"
			_action_button.text = "Refuel (Free) & Return"
		FleetAircraft.State.FLYING_BACK:
			_status.text = "Returning home - %ds left" % ceili(a.flight_time_left)
			_action_button.visible = false
		FleetAircraft.State.AWAITING_HOME_CLAIM:
			_status.text = "Landed home"
			_action_button.text = "Claim $%d" % Fleet.REWARD_AT_HOME
		FleetAircraft.State.AWAITING_HOME_REFUEL:
			_status.text = "Needs %d fuel to park" % Fleet.FUEL_PER_TRIP
			_action_button.text = "Refuel & Park"
			_action_button.disabled = FuelStore.amount < Fleet.FUEL_PER_TRIP


func _refresh_skin_slot() -> void:
	var entry := ApronSkins.get_skin_entry(_apron_id)
	if entry.size() > 0:
		_skin_preview.texture = load(entry["texture"])
		_skin_preview.visible = true
		_skin_empty_label.visible = false
		_skin_bonus_label.text = "+%d%% bonus" % ApronSkins.BONUS_PERCENT
		_skin_button.text = "Change Skin"
	else:
		_skin_preview.visible = false
		_skin_empty_label.visible = true
		_skin_bonus_label.text = "No bonus"
		_skin_button.text = "Choose Skin"


func _on_skin_button_pressed() -> void:
	get_node("../SkinPickerPanel").show_for_apron(_apron_id)


func _refresh_plane_slot(a: FleetAircraft) -> void:
	if not a:
		_plane_icon.visible = false
		_plane_empty_label.visible = true
		_plane_button.text = "Assign"
		_plane_button.disabled = false
		return

	var entry := _catalog_entry(a.model_key)
	if entry.size() > 0:
		_plane_icon.texture = load("res://assets/shop/%s" % entry["icon"])
		_plane_icon.visible = true
	_plane_empty_label.visible = false
	_plane_button.text = "Replace"
	# Only a parked aircraft can be pulled back to reassign - one mid-route
	# doesn't make sense to just vanish (matches Fleet.unassign's own rule).
	_plane_button.disabled = a.state != FleetAircraft.State.PARKED


func _on_plane_button_pressed() -> void:
	var a := Fleet.get_aircraft_at_apron(_apron_id)
	if a:
		Fleet.unassign(a.id)
	get_node("../AssignPickerPanel").show_for_apron(_apron_id)


func _catalog_entry(model_key: String) -> Dictionary:
	for entry in ShopCatalog.ENTRIES:
		if entry["key"] == model_key:
			return entry
	return {}


func _on_action_pressed() -> void:
	if not (_apron and (_apron.built or ApronProgress.is_built(_apron_id))):
		ApronProgress.build(_apron_id, _apron.area_name)
		return
	var a := Fleet.get_aircraft_at_apron(_apron_id)
	if not a:
		return
	match a.state:
		FleetAircraft.State.PARKED:
			Fleet.fuel_and_depart(a.id)
		FleetAircraft.State.AWAITING_DEST_CLAIM:
			Fleet.claim_destination_reward(a.id)
		FleetAircraft.State.AWAITING_DEST_REFUEL:
			Fleet.refuel_at_destination(a.id)
		FleetAircraft.State.AWAITING_HOME_CLAIM:
			Fleet.claim_home_reward(a.id)
		FleetAircraft.State.AWAITING_HOME_REFUEL:
			Fleet.refuel_at_home(a.id)
