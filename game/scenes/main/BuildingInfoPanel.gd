extends Control

# What's standing on this plot, and the one thing you can do about it.
#
# The Prop Shop used to do this job as well - it opened on an occupied site,
# greyed all four cards to "Site taken" and grew a Demolish button. That made
# the shop mean two different things depending on what you tapped, and it made
# the demolish button share a window with four buy buttons, which is the last
# place a destructive action should live.
#
# Built on board_buildinginfo@2x, the same board ApronInfoPanel uses, because it
# answers the same shape of question about the other kind of plot: what is here,
# what is it doing, and what can I change.
const BOARD := preload("res://assets/board/board_buildinginfo@2x.png")
const FRAME_FILLED := preload("res://assets/board/board_apron_info_icon2@2x.png")
const DEMOLISH_NORMAL := preload("res://assets/buttons/button_red1@2x.png")
const DEMOLISH_ARMED := preload("res://assets/buttons/button_red2@2x.png")
# Orange for the thing you want to press, the same as everywhere else here.
const UPGRADE_NORMAL := preload("res://assets/buttons/button_orange2@2x.png")
const UPGRADE_OFF := preload("res://assets/buttons/button_grey3@2x.png")

const BOARD_NATIVE := Vector2(731, 177)
const BOARD_SCALE := 0.82
const BOARD_SIZE := Vector2(599, 145)

const TITLE_Y := 0.0
const SLOT_X := 0.065
const SLOT_Y := 0.13
const SLOT_W := 0.20
const SLOT_H := 0.45
# The three numbers that decide whether this building deserves its plot.
const STAT_X := 0.315
const STAT_Y := 0.20
const STAT_STEP := 0.19
const ACTION_X := 0.775
# Between Demolish and Upgrade, which sit side by side centred on ACTION_X.
const BUTTON_GAP := 12.0
const ACTION_Y := 0.30

const FONT_TITLE := 15
const FONT_NAME := 14
const FONT_STAT := 13
const FONT_BUTTON := 13
const FONT_NOTE := 11
const FONT_MIN := 9

var _plot_id: int = -1
var _content: Control
var _title: Label
var _frame: TextureRect
var _art: TextureRect
var _name: Label
var _stats: Array[Label] = []
var _button: TextureButton
var _button_label: Label
var _upgrade: TextureButton
var _upgrade_label: Label
var _note: Label
# Not undoable and it costs you half - so the first press arms and the second
# does it, same as the options menu's reset and for the same reason.
var _armed := false


func _ready() -> void:
	visible = false
	custom_minimum_size = BOARD_SIZE
	size = BOARD_SIZE

	var board := TextureRect.new()
	board.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	board.stretch_mode = TextureRect.STRETCH_SCALE
	board.texture = BOARD
	board.size = BOARD_SIZE
	board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(board)

	_content = Control.new()
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_build()

	BuildingProgress.built_changed.connect(_refresh)
	BuildingProgress.rent_changed.connect(_refresh)


func _px(fx: float, fy: float) -> Vector2:
	return Vector2(BOARD_SIZE.x * fx, BOARD_SIZE.y * fy)


func _fs(native: int) -> int:
	return maxi(FONT_MIN, roundi(native * BOARD_SCALE))


func _build() -> void:
	_title = _label(_fs(FONT_TITLE), HORIZONTAL_ALIGNMENT_LEFT)
	_title.position = _px(SLOT_X, TITLE_Y)
	_title.size = _px(0.4, 0.13)

	_frame = TextureRect.new()
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.texture = FRAME_FILLED
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.position = _px(SLOT_X, SLOT_Y)
	_frame.size = _px(SLOT_W, SLOT_H)
	_content.add_child(_frame)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.position = _px(SLOT_X + 0.02, SLOT_Y + 0.05)
	_art.size = _px(SLOT_W - 0.04, SLOT_H - 0.10)
	_content.add_child(_art)

	_name = _label(_fs(FONT_NAME), HORIZONTAL_ALIGNMENT_CENTER)
	_name.position = _px(SLOT_X - 0.02, SLOT_Y + SLOT_H + 0.02)
	_name.size = _px(SLOT_W + 0.04, 0.16)

	for i in range(3):
		var l := _label(_fs(FONT_STAT), HORIZONTAL_ALIGNMENT_LEFT)
		l.position = _px(STAT_X, STAT_Y + STAT_STEP * i)
		l.size = _px(0.42, 0.18)
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_stats.append(l)

	# Drawn at the art's own aspect - see ApronInfoPanel._button for why every
	# button in this project derives its width rather than being given one.
	# 1x NATIVE: the button art is @2x, so half its pixels is its intended size.
	var h: float = DEMOLISH_NORMAL.get_height() * 0.5
	var w: float = DEMOLISH_NORMAL.get_width() * 0.5
	_button = TextureButton.new()
	_button.ignore_texture_size = true
	_button.stretch_mode = TextureButton.STRETCH_SCALE
	_button.texture_normal = DEMOLISH_NORMAL
	_button.size = Vector2(w, h)
	# PAIRED, not mirrored. Upgrade was placed at the mirror of ACTION_X, which
	# on a 599-wide board put it at x 97-173 - straight on top of the building's
	# own artwork (the slot runs 39-159). The two actions belong together in the
	# action column anyway: they are the two things you can do to this plot.
	_button.position = Vector2(BOARD_SIZE.x * ACTION_X - w - BUTTON_GAP * 0.5,
		BOARD_SIZE.y * ACTION_Y)
	_button.pressed.connect(_on_pressed)
	add_child(_button)

	_button_label = Label.new()
	_button_label.add_theme_font_size_override("font_size", _fs(FONT_BUTTON))
	_button_label.add_theme_color_override("font_color", Color(1, 0.96, 0.92))
	_button_label.add_theme_color_override("font_outline_color", Color(0.26, 0.06, 0.03, 1))
	_button_label.add_theme_constant_override("outline_size", 4)
	_button_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_button_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_button_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_button_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_button_label.anchor_right = 1.0
	_button_label.anchor_bottom = 1.0
	_button.add_child(_button_label)

	# Upgrade sits beside Demolish, same shape, opposite intent - one makes the
	# plot worth more, the other gives up on it.
	_upgrade = TextureButton.new()
	_upgrade.ignore_texture_size = true
	_upgrade.stretch_mode = TextureButton.STRETCH_SCALE
	_upgrade.texture_normal = UPGRADE_NORMAL
	_upgrade.size = Vector2(w, h)
	_upgrade.position = Vector2(BOARD_SIZE.x * ACTION_X + BUTTON_GAP * 0.5,
		BOARD_SIZE.y * ACTION_Y)
	_upgrade.pressed.connect(_on_upgrade_pressed)
	add_child(_upgrade)

	_upgrade_label = Label.new()
	_upgrade_label.add_theme_font_size_override("font_size", _fs(FONT_BUTTON))
	_upgrade_label.add_theme_color_override("font_color", Color(1, 0.97, 0.90))
	_upgrade_label.add_theme_color_override("font_outline_color", Color(0.30, 0.15, 0.02, 1))
	_upgrade_label.add_theme_constant_override("outline_size", 4)
	_upgrade_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_upgrade_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_upgrade_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_upgrade_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_upgrade_label.anchor_right = 1.0
	_upgrade_label.anchor_bottom = 1.0
	_upgrade.add_child(_upgrade_label)

	_note = _label(_fs(FONT_NOTE), HORIZONTAL_ALIGNMENT_CENTER)
	_note.position = _px(ACTION_X - 0.20, ACTION_Y + 0.26)
	_note.size = _px(0.40, 0.14)
	_note.add_theme_color_override("font_color", Color(0.95, 0.82, 0.72))

	CloseButton.add_to(self, BOARD_SIZE, _close)


func _label(size_px: int, align: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", size_px)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.16, 0.09, 0.03, 1))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(l)
	return l


func show_plot(plot_id: int) -> void:
	if not BuildingProgress.is_built(plot_id):
		return
	_plot_id = plot_id
	_armed = false
	move_to_front()
	visible = true
	_refresh()


func _close() -> void:
	_armed = false
	visible = false


func _refresh(_a = null, _b = null) -> void:
	if not visible or _plot_id < 0:
		return
	var key := BuildingProgress.building_at(_plot_id)
	# Demolished out from under us, or the map changed - there is nothing left
	# to describe, so stop describing it.
	if key == "":
		_close()
		return

	_title.text = "Site %d" % _plot_id
	var path := BuildingLayout.texture_path(key)
	_art.texture = load(path) if ResourceLoader.exists(path) else null
	_name.text = BuildingLayout.name_of(key)

	var level := BuildingProgress.level_at(_plot_id)
	_name.text = "%s   Lv %d" % [BuildingLayout.name_of(key), level]
	# The PLOT's rent, not the building type's - a level that did not show here
	# would be a level that silently did not count.
	_stats[0].text = "Rent  $%s  every %d min" % [
		_thousands(BuildingProgress.rent_at(_plot_id)),
		int(BuildingLayout.cycle_seconds(key) / 60.0)]
	_stats[1].text = "Inhabitants  %s" % _thousands(BuildingLayout.people_of(key))
	var upgrading := BuildingProgress.is_upgrading(_plot_id)
	var ready := BuildingProgress.is_rent_ready(_plot_id)
	if upgrading:
		# Says WHY it is not earning, rather than showing a rent timer that is
		# not running.
		_stats[2].text = "Upgrading - no rent for %s" % _countdown(
			BuildingProgress.upgrade_seconds_left(_plot_id))
	else:
		_stats[2].text = ("Rent ready to collect" if ready
			else "Next rent in %s" % _countdown(BuildingProgress.seconds_until_ready(_plot_id)))
	_refresh_upgrade(key, level, upgrading)

	_button.texture_normal = DEMOLISH_ARMED if _armed else DEMOLISH_NORMAL
	_button_label.text = "Confirm" if _armed else "Demolish"
	# Says what it gives back and what it takes away. The inhabitants are the
	# part people forget - popularity is a multiplier on every flight, so
	# clearing a plot costs more than the difference in rent.
	_note.text = ("Refunds %s, and %s inhabitants leave"
		% [_refund_text(key), _thousands(BuildingLayout.people_of(key))]
		if _armed
		else "Clear this site  (+%s)" % _refund_text(key))


# Three states: buildable, already running, or maxed out.
func _refresh_upgrade(key: String, level: int, upgrading: bool) -> void:
	if level >= BuildingProgress.MAX_LEVEL:
		_upgrade.texture_normal = UPGRADE_OFF
		_upgrade.disabled = true
		_upgrade_label.text = "Max level"
		return
	if upgrading:
		_upgrade.texture_normal = UPGRADE_OFF
		_upgrade.disabled = true
		_upgrade_label.text = _countdown(BuildingProgress.upgrade_seconds_left(_plot_id))
		return
	var cost := BuildingProgress.upgrade_cost(_plot_id)
	# Priced in whatever the building was bought with - a coin building upgrades
	# with coins, so both the check and the caption have to follow it.
	var in_coins := BuildingProgress.upgrade_currency(_plot_id) == "coins"
	var affordable := (Coins.amount >= cost) if in_coins else (Economy.money >= cost)
	_upgrade.texture_normal = UPGRADE_NORMAL if affordable else UPGRADE_OFF
	_upgrade.disabled = not affordable
	# JUST THE VERB. This used to read "Lv 4  110,000 coins" - a level the
	# building's own name already shows, a price, and no answer to the only
	# question worth asking, which is what the money buys. That is what
	# UpgradeConfirmPanel is for, and pressing this opens it.
	_upgrade_label.text = "Upgrade"
	_note_upgrade(key, level, cost, affordable, in_coins)


# THE PRICE APPEARS ONLY WHEN YOU CANNOT PAY IT, which is the one time it is
# any use. It was taken out of here on purpose - a price with no answer to what
# the money buys is noise, and UpgradeConfirmPanel gives both. But that panel
# opens from a button that is DISABLED until you can afford it, so the cost was
# locked behind a door that only opens once you no longer need to ask. Short of
# the money, the note says how much; able to pay, the confirm panel takes over
# and the note stays about what the money buys.
func _note_upgrade(_key: String, level: int, cost: int, affordable: bool,
		in_coins: bool) -> void:
	if _armed or level >= BuildingProgress.MAX_LEVEL:
		return
	var now: int = BuildingProgress.rent_at(_plot_id)
	var after: int = BuildingProgress.rent_at_level(
		BuildingProgress.building_at(_plot_id), level + 1)
	var text := "Upgrade: rent $%s -> $%s, off service %s" % [
		_thousands(now), _thousands(after),
		_countdown(BuildingProgress.upgrade_seconds(_plot_id))]
	if not affordable:
		text += "   -   costs %s" % (("%d coins" % cost) if in_coins
			else "$%s" % _thousands(cost))
	_note.text = text


func _on_upgrade_pressed() -> void:
	if _plot_id < 0:
		return
	# Ask before spending. The confirm window does the upgrade itself and calls
	# back so this panel picks up the new level and the countdown.
	var confirm := get_node_or_null("../UpgradeConfirmPanel")
	if confirm == null:
		# No window in this scene - do what the button always did rather than
		# silently doing nothing.
		if BuildingProgress.start_upgrade(_plot_id):
			_refresh()
		return
	confirm.show_for_plot(_plot_id, _refresh)


func _on_pressed() -> void:
	if _plot_id < 0 or not BuildingProgress.is_built(_plot_id):
		return
	if not _armed:
		_armed = true
		_refresh()
		return
	var plot := _plot_id
	BuildingProgress.demolish(plot)
	_armed = false
	visible = false
	# THIS USED TO OPEN THE PROP SHOP on the plot just cleared, on the
	# reasoning that clearing a site is the first half of building something
	# better. Played, it is wrong: clearing several sites is the common case,
	# and every demolish threw a shop window in front of the next building the
	# player was trying to reach. Closing and getting out of the way costs one
	# press when the guess would have been right, against one press to dismiss
	# every time it is not.


func _refund_text(building_key: String) -> String:
	var refund := BuildingProgress.refund_for(_plot_id)
	if BuildingLayout.currency_of(building_key) == "coins":
		return "%d coins" % refund
	return "$%s" % _thousands(refund)


func _countdown(secs: float) -> String:
	var t := int(ceilf(secs))
	if t >= 3600:
		return "%dh %02dm" % [t / 3600, (t % 3600) / 60]
	if t >= 60:
		return "%dm %02ds" % [t / 60, t % 60]
	return "%ds" % t


func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return out
