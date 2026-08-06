extends HBoxContainer

@onready var _money_label: Label = $MoneyLabel
@onready var _coin_label: Label = $CoinLabel
@onready var _fuel_label: Label = $FuelLabel
@onready var _people_label: Label = $PeopleLabel


func _ready() -> void:
	# The gear lives in TopBarRight but the panel it opens is a sibling of the
	# whole HUD, so the wiring is done here rather than in another script whose
	# only job would be one connect().
	var gear := get_node_or_null("../TopBarRight/OptionsButton")
	if gear:
		gear.pressed.connect(_on_options_pressed)
	Economy.money_changed.connect(_on_money_changed)
	_on_money_changed(Economy.money)
	Coins.coins_changed.connect(_on_coins_changed)
	_on_coins_changed(Coins.amount)
	FuelStore.fuel_changed.connect(_on_fuel_changed)
	_on_fuel_changed(FuelStore.amount)
	# The city's population, which is what buildings are really for - it adds a
	# percentage to every flight (see BuildingProgress.PEOPLE_PER_PERCENT).
	# Redrawn when a building goes up, and when travelling, since inhabitants
	# are counted per airport.
	BuildingProgress.built_changed.connect(_on_people_changed)
	Maps.map_changed.connect(_on_people_changed)
	_on_people_changed()


func _on_options_pressed() -> void:
	var panel := get_node_or_null("../OptionsPanel")
	if panel and panel.has_method("open"):
		panel.open()


func _on_money_changed(amount: int) -> void:
	_money_label.text = str(amount)


func _on_coins_changed(amount: int) -> void:
	_coin_label.text = str(amount)


func _on_fuel_changed(amount: int) -> void:
	# Just the number - the drum icon beside it carries the meaning, matching
	# how money and coins read.
	_fuel_label.text = str(amount)


# Shows the bonus rather than the raw head count, because the percentage is the
# part that means anything - "720" says nothing on its own, "720 (+2.9%)" says
# what the buildings are doing for you.
func _on_people_changed(_unused = null) -> void:
	var people := BuildingProgress.total_people()
	var pct := BuildingProgress.popularity_percent()
	_people_label.text = "%d (+%.1f%%)" % [people, pct] if people > 0 else "0"
