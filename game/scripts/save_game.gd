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
# Progress, so it lives in user:// - see SavePaths.
const SAVE_FILE := "player.json"

# Writes are debounced rather than done on every signal - claiming a reward
# alone fires money, XP and fleet changes together.
const SAVE_DEBOUNCE := 1.0

# WHICH BUILD WROTE THIS SAVE. Balance moves; a save carrying a level and a
# fleet says nothing useful once the prices under it have changed, and two
# testers on two builds cannot be compared without knowing they differ.
#
# Set by hand, and OFF BY ONE on purpose: it names the commit that introduced
# the code, not the commit that set the string, because a stamp cannot contain
# the hash of the commit that contains it. Close enough to tell two builds
# apart, which is all it is for.
const BUILD := "07985f4"

# TELEMETRY, and the reason it exists: a save is a SNAPSHOT. It says where a
# player got to and never how long it took, so the one thing it cannot answer
# is the one thing balance keeps asking - pacing. A tester reaching level 40
# in two hours and in twenty writes the identical file.
#
# level_at is the valuable one: unix time against each level the moment it was
# first reached, so a single save carries the player's whole progression curve
# and can be laid straight beside a --bot run's day-by-day table.
var played_seconds := 0.0
var earned_total := 0
var level_at := {}
var _earn_mark := -1

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
	Economy.money_changed.connect(_on_money)
	Progression.level_changed.connect(_on_level)
	# Whatever was loaded is the starting point, not income - without this the
	# balance restored at boot is counted as earnings on every single launch.
	_earn_mark = Economy.money


func _process(delta: float) -> void:
	# Wall-clock time with the game actually open. Counted before the dirty
	# check, or a session where nothing happens would not count at all.
	played_seconds += delta
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


# GROSS income, not net worth: every upward move of the balance, so spending
# does not cancel out what was earned to afford it.
func _on_money(amount: int) -> void:
	if _earn_mark >= 0 and amount > _earn_mark:
		earned_total += amount - _earn_mark
	_earn_mark = amount


# First time only - a level is reached once, and re-firing must not move the
# timestamp that makes the curve readable.
func _on_level(level: int) -> void:
	var key := str(level)
	if not level_at.has(key):
		level_at[key] = GameClock.now()
		_mark_dirty()


# THE BOT MUST NEVER WRITE THE PLAYER'S SAVE.
#
# It calls reset_to_defaults() at the start of every run and then plays 90
# simulated days - and every one of those days was being written straight over
# a real playthrough. A session of bot runs silently replaced a level 24 airport
# with a level 1 one, and the only reason it was noticed is that the progress
# files went missing too.
#
# Refusing here rather than in the bot: anything that drives the autoloads
# headless has the same problem, and there is exactly one place a save is
# written.
# PUBLIC, because this is not one file's rule - it is the invariant that a bot
# run writes NOTHING to res://data. It has been enforced per-file three times and
# leaked three times, most recently through ApronSkins, which destroyed a real
# playthrough. Every writer in scripts/ calls this now.
func is_bot_run() -> bool:
	return OS.get_cmdline_user_args().has("--bot")


func _is_headless_bot() -> bool:
	return is_bot_run()


func save() -> void:
	if _is_headless_bot():
		return
	_dirty = false
	_timer = 0.0
	var data := {
		"saved_at": GameClock.now(),
		"money": Economy.money,
		"coins": Coins.amount,
		"fuel": FuelStore.amount,
		"fuel_orders": FuelStore.to_save(),
		"xp": Progression.xp,
		"level": Progression.level,
		"fleet": Fleet.to_save(),
		"quests": Quests.to_save(),
		"daily_login": DailyLogin.to_save(),
		"boosts": Boosts.to_save(),
		"build": BUILD,
		"played_seconds": int(played_seconds),
		"earned_total": earned_total,
		"level_at": level_at,
	}
	var f := FileAccess.open(SavePaths.write_path(SAVE_FILE), FileAccess.WRITE)
	if not f:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func _load() -> void:
	_loaded = true
	if not SavePaths.read_path(SAVE_FILE) != "":
		# No save at all, so this is a brand-new game: hand over the starter
		# DC-3. Done here rather than in Fleet._ready because this autoload
		# comes up last and is the only one that knows a fresh game from a
		# loaded one - see the order in project.godot.
		Fleet.grant_starter()
		# A fresh game draws a fresh set of daily tasks, sized to the fleet it
		# now has rather than to whatever the last save owned.
		Quests.reset()
		return
	var f := FileAccess.open(SavePaths.read_path(SAVE_FILE), FileAccess.READ)
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
	var orders: Variant = data.get("fuel_orders", null)
	if orders is Array:
		FuelStore.load_save(orders)
	# Set XP without going through add_xp, or reloading would re-fire every
	# level-up signal the player already saw.
	Progression.xp = int(data.get("xp", 0))
	Progression.level = maxi(1, int(data.get("level", 1)))

	played_seconds = float(data.get("played_seconds", 0))
	earned_total = int(data.get("earned_total", 0))
	var seen: Variant = data.get("level_at", null)
	level_at = seen if seen is Dictionary else {}

	var quest_data: Variant = data.get("quests", null)
	if quest_data is Dictionary:
		Quests.load_save(quest_data)

	var login_data: Variant = data.get("daily_login", null)
	if login_data is Dictionary:
		DailyLogin.load_save(login_data)

	var boost_data: Variant = data.get("boosts", null)
	if boost_data is Dictionary:
		Boosts.load_save(boost_data)

	var elapsed := 0.0
	var saved_at := float(data.get("saved_at", 0.0))
	if saved_at > 0.0:
		elapsed = maxf(0.0, GameClock.now() - saved_at)
	var fleet_data: Variant = data.get("fleet", null)
	if fleet_data is Dictionary and not (fleet_data as Dictionary).get("aircraft", []).is_empty():
		Fleet.load_save(fleet_data, elapsed)


# For the debug menu / starting over.
func wipe() -> void:
	# Same rule as save(): a bot run resets its own in-memory state, it does not
	# delete the player's files.
	if _is_headless_bot():
		return
	_remove(SAVE_FILE)


# Both copies. user:// is where it lives now; the res://data one is what an
# existing playthrough is still being read from until its first save, and
# leaving it behind would resurrect the world the next time the game started.
static func _remove(file_name: String) -> void:
	for path in [SavePaths.write_path(file_name),
			"%s/%s" % [SavePaths.LEGACY_DIR, file_name]]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# Every file the player's progress lives in - NOT the authored level data.
#
# That split is the whole point. apron_layout, cloud_layout, building_layout,
# paths and aircraft_rig are hand-placed level design that ships with the game;
# wiping those would destroy work no player could recreate. These five are
# somebody's playthrough.
# Names, not paths - _remove takes both copies of each.
const PROGRESS_FILES := [
	"apron_progress.json",
	"zone_progress.json",
	"apron_skins.json",
	"apron_skins_owned.json",
	"aircraft_affinity.json",
	"building_progress.json",
	"friends.json",
]


# Back to a brand new game, in memory AND on disk.
#
# Deleting the files alone is not enough: every autoload is already holding its
# state, and the next save would write it all straight back out. So each one is
# reset in place too, and the save is disarmed while that happens or the
# debounce timer would persist a half-cleared world.
func reset_to_defaults() -> void:
	_dirty = false
	wipe()
	# Deleting the progress files is the OTHER way a bot run destroyed a real
	# playthrough - wipe() and the per-system _save()s are both guarded, but
	# this loop reached past them straight to the filesystem. A bot resets its
	# own in-memory state; the files on disk are the player's.
	if not _is_headless_bot():
		for file_name in PROGRESS_FILES:
			_remove(file_name)

	# Back to real time too - a reset that kept a 300x scale running would look
	# like the fresh game was broken.
	GameClock.reset()
	Economy.money = Economy.STARTING_MONEY
	Coins.amount = Coins.DEFAULT_AMOUNT
	DailyLogin.reset()
	Boosts.reset()
	FuelStore.amount = FuelStore.STARTING_AMOUNT
	Progression.xp = 0
	Progression.level = 1
	Fleet.aircraft.clear()
	Fleet.reset_ids()
	# A reset is a fresh game, and a fresh game is handed a DC-3 on apron 1 -
	# see Fleet._ready. Clearing to nothing would drop the player into exactly
	# the opening that was just fixed.
	Fleet.grant_starter()
	# A fresh game draws a fresh set of daily tasks, sized to the fleet it now
	# has rather than to whatever the last save owned.
	Quests.reset()
	ApronProgress.built_ids.clear()
	ZoneProgress.unlocked_zones.clear()
	AircraftAffinity.reset()
	ApronSkins.reset()
	BuildingProgress.built.clear()

	# Everything that draws from the above has to be told, or the world keeps
	# showing the airport you just deleted until something else happens to
	# trigger a rebuild.
	Progression.xp_changed.emit(0)
	Progression.level_changed.emit(1)
	ApronProgress.built_changed.emit()
	ZoneProgress.unlocked_changed.emit()
	AircraftAffinity.affinity_changed.emit()
	ApronSkins.skin_changed.emit()
	BuildingProgress.built_changed.emit()
	Fleet.fleet_changed.emit()
	_dirty = false
