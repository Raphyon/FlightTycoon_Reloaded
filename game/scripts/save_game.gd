extends Node

# The player's save: money, coins, fuel, level and the fleet - including which
# aircraft are mid-route and how far along they are.
#
# Why one file rather than the per-autoload pattern the rest of the project
# uses (ApronProgress, ZoneProgress, Friends and AircraftAffinity each own a
# JSON): these five are one state. Saving them separately means a crash
# between writes can leave money spent with the aircraft it bought missing, or
# a fleet mid-route against a level that can't fly it. One file is one
# consistent snapshot.
#
# Everything here used to be volatile. Zones and aprons persisted but the money
# paid for them did not, so every boot handed back the balance AND kept the
# purchases - and any aircraft out on a route simply vanished.
#
# KNOWN LIMITATION, shared with all four existing save files: res:// is
# read-only in an exported game, so these only persist when running from the
# editor. Fine for the prototype; moving all five to user:// is a job in
# itself and shouldn't happen piecemeal.
const SAVE_PATH := "res://data/player.json"

# Writes are debounced rather than done on every signal - claiming a reward
# alone fires money, XP and fleet changes together.
const SAVE_DEBOUNCE := 1.0

var _dirty := false
var _timer := 0.0
var _loaded := false


func _ready() -> void:
	# After the autoloads it reads from - see the order in project.godot.
	_load()
	Fleet.fleet_changed.connect(_mark_dirty)
	Economy.money_changed.connect(_mark_dirty.unbind(1))
	Coins.coins_changed.connect(_mark_dirty.unbind(1))
	FuelStore.fuel_changed.connect(_mark_dirty.unbind(1))
	Progression.xp_changed.connect(_mark_dirty.unbind(1))


func _process(delta: float) -> void:
	if not _dirty:
		return
	_timer += delta
	if _timer >= SAVE_DEBOUNCE:
		save()


func _notification(what: int) -> void:
	# Quitting is the one moment a debounced write would be lost.
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		if _loaded and _dirty:
			save()


func _mark_dirty() -> void:
	_dirty = true


func save() -> void:
	_dirty = false
	_timer = 0.0
	var data := {
		"saved_at": Time.get_unix_time_from_system(),
		"money": Economy.money,
		"coins": Coins.amount,
		"fuel": FuelStore.amount,
		"xp": Progression.xp,
		"level": Progression.level,
		"fleet": Fleet.to_save(),
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not f:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _load() -> void:
	_loaded = true
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not f:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Dictionary):
		return
	var data: Dictionary = parsed

	Economy.money = int(data.get("money", Economy.money))
	Coins.amount = int(data.get("coins", Coins.amount))
	FuelStore.amount = int(data.get("fuel", FuelStore.amount))
	# Set XP without going through add_xp, or reloading would re-fire every
	# level-up signal the player already saw.
	Progression.xp = int(data.get("xp", 0))
	Progression.level = maxi(1, int(data.get("level", 1)))

	var elapsed := 0.0
	var saved_at := float(data.get("saved_at", 0.0))
	if saved_at > 0.0:
		elapsed = maxf(0.0, Time.get_unix_time_from_system() - saved_at)
	var fleet_data: Variant = data.get("fleet", null)
	if fleet_data is Dictionary and not (fleet_data as Dictionary).get("aircraft", []).is_empty():
		Fleet.load_save(fleet_data, elapsed)


# For the debug menu / starting over.
func wipe() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
