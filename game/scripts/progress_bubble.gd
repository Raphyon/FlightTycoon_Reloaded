class_name ProgressBubble
extends Control

# THE SWOOP. A callout that, once tapped, spends two seconds visibly doing the
# thing before it hands over the money.
#
# WHY a claim is not instant any more. Tapping a bubble used to be the whole
# transaction: the cash appeared, the bubble vanished, and a round trip that took
# twenty minutes of real time resolved in a frame. Nothing on screen ever showed
# an airport WORKING - it only showed work finishing. Two seconds of a bar
# filling is the difference between collecting a number and servicing an
# aircraft.
#
# IT DOES NOT BLOCK. The swoop runs on its own and the rest of the airport stays
# live, so you can start one on every pad and let them all run at once. That is
# deliberate and it is load-bearing: taps are the binding constraint in this game
# (a regular player is measured at ~34 a minute, and the bot's 60-hour run spends
# 121,000 of them), so a claim that had to be watched before the next one could
# start would halve what a session gets through. Fire and move on.
#
# The art is a family of 96x58 bubbles with the icon baked into the top-left and
# the rest of the oval left empty for exactly this: a line of text and a bar.
# Nothing here is centred on the canvas - the tail sits at x=23.5, well left of
# middle, so the bubble is placed BY ITS TAIL like the arrived callout already
# was.

# The art's own size. Drawn 1:1 - the source is trimmed flush to content.
const BUBBLE_SIZE := Vector2(96, 58)
# Where the tail tip lands within that canvas, measured off the alpha: the
# bottom-most opaque row is y=56, spanning x 23..24.
#
# THE TAIL IS WHY THIS ONLY BELONGS ON THE BOARD. It is a POINTER: it hangs
# above a pad or a plot and its tip names which one it is talking about. That
# only means something where the thing being pointed at is somewhere on screen
# with the bubble floating over it.
#
# A LIST ROW IS NOT THAT. The row IS the subject - it is already labelled, in
# its own strip, in line with fifty others - so a tail points at nothing and the
# oval is just a 96x58 lump in a 52px row. RoutesPanel had one for two commits
# and it was wrong in a way that is obvious on sight and easy to argue into on
# paper, because "the pads do it" sounds like consistency.
#
# Use a bare track-and-fill in a list, in the colours below so a claim still
# reads the same. See RoutesPanel's SWOOP_BAR_SIZE.
const TAIL := Vector2(23.5, 56.0)

# The empty field inside the oval, in bubble pixels.
#
# MEASURED OFF THE ART, not guessed, because the oval is an oval: its right edge
# runs out to x=92 at y=22 but pulls back to x=81 by y=36. The first pass put a
# 54-wide bar at y=26..36 and its right end finished outside the bubble on the
# lower rows. Only the icon is meant to break the outline.
#
# Rows the bar sits on (y=24..33) hold x=2..87 at their narrowest, and the
# baked icon reaches x=17, so 28..78 clears both with room to spare.
const TEXT_CENTER := Vector2(55, 13)
const BAR_RECT := Rect2(28, 24, 50, 9)
# Rounded to match the art. Square corners on a bar sitting inside a soft
# airbrushed oval read as a debug overlay, which is what the first pass looked
# like.
const BAR_RADIUS := 4
const BAR_INSET := 2.0

const FILL_SECONDS := 2.0

const COLOR_TRACK := Color(0.16, 0.16, 0.18, 0.75)
const COLOR_EARN := Color(0.47, 0.86, 0.51)
const COLOR_FUEL := Color(0.94, 0.71, 0.24)
# TYPE. The bubble is 58 pixels tall and the label sits in a band about 14 of
# them deep, so 16pt bold with a 5px outline filled the oval wall to wall - it
# read as a warning sticker rather than a caption.
#
# Plain weight, dark on the light oval, no outline. The bubble art is its own
# contrast; an outline is for text over the world, which this is not (see
# FloatingText, which does sit over the world and keeps one).
const COLOR_TEXT := Color(0.09, 0.09, 0.10)
const FONT_SIZE := 11
const OUTLINE_SIZE := 0

signal completed

var _bubble: TextureRect
var _label: Label
var _fill := 0.0
var _running := false
var _bar_color := COLOR_EARN
var _on_done: Callable = Callable()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = BUBBLE_SIZE
	_bubble = TextureRect.new()
	_bubble.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bubble.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# Minimum first, THEN the size. A TextureRect's own art is its minimum
	# size until expand_mode says otherwise, so assigning a smaller size
	# before this line is silently clamped straight back up - which is why
	# shrinking these icons appeared to do nothing at all.
	_bubble.custom_minimum_size = Vector2.ZERO
	_bubble.size = BUBBLE_SIZE
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# BEHIND THE PARENT, or it covers the bar. A node's own _draw runs before
	# its children are drawn, so this TextureRect - 96x58 of opaque oval -
	# painted straight over the bar every frame. The text was fine because a
	# Label is a child too and lands on top of both.
	_bubble.show_behind_parent = true
	add_child(_bubble)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", COLOR_TEXT)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Sized and placed around TEXT_CENTER rather than filling the control, so
	# the line stays clear of the baked icon on the left.
	_label.size = Vector2(BUBBLE_SIZE.x - TEXT_CENTER.x * 0.5, 20)
	_label.position = Vector2(TEXT_CENTER.x - _label.size.x * 0.5,
		TEXT_CENTER.y - _label.size.y * 0.5)
	add_child(_label)


# Start a swoop. `action` is called when the bar fills, NOT when the tap lands -
# the bar IS the transaction, so the money is earned and the fuel is spent when
# it finishes, and the figures that pop off the bubble are those of the moment
# it landed rather than of the moment it was tapped.
func run(texture: Texture2D, text: String, action: Callable, fuel := false) -> void:
	_bubble.texture = texture
	_label.text = text
	_bar_color = COLOR_FUEL if fuel else COLOR_EARN
	_on_done = action
	_fill = 0.0
	_running = true
	visible = true
	set_process(true)
	queue_redraw()


# A STATIC display rather than a swoop: a countdown, or an arrived tag. Same
# bubble, same bar, but nothing is being timed by this node - the caller owns
# the numbers and pushes them in.
func show_status(texture: Texture2D, text: String, fill: float, fuel := false) -> void:
	_bubble.texture = texture
	_label.text = text
	_bar_color = COLOR_FUEL if fuel else COLOR_EARN
	_fill = clampf(fill, 0.0, 1.0)
	_running = false
	set_process(false)
	visible = true
	queue_redraw()


func is_running() -> bool:
	return _running


# Deliberately NOT tied to GameClock. This is an animation the player watches,
# and under fast-forward the world moving 300x should not turn a two second
# swoop into a single frame - the same reason GameClock leaves the engine at 1x.
func _process(delta: float) -> void:
	if not _running:
		return
	_fill = minf(1.0, _fill + delta / FILL_SECONDS)
	queue_redraw()
	if _fill >= 1.0:
		_running = false
		set_process(false)
		var action := _on_done
		_on_done = Callable()
		if action.is_valid():
			_call_and_report(action)
		completed.emit()


# Runs the action and floats what it actually DID above the bubble.
#
# Measured as a before/after delta rather than asked for in advance. Predicting
# it would mean a second copy of the payout expression - and the amount is not
# even knowable up front in every case, because a rent claim can turn up a coin
# on a dice roll (BuildingProgress.coin_chance_for). A delta reports whatever
# happened, including the parts nothing predicted.
# Set by the signal while an action runs; read once the action is done.
var _levelled_to := 0


func _on_model_levelled(_model_key: String, level: int, _reward: int) -> void:
	_levelled_to = level


func _call_and_report(action: Callable) -> void:
	var money_before: int = Economy.money
	var fuel_before: int = FuelStore.amount
	var coins_before: int = Coins.amount
	# Progression.xp is cumulative and never resets - level is derived from
	# thresholds - so a plain delta is safe across a level-up.
	var xp_before: int = Progression.xp

	# A model levelling is folded into the money delta above - the reward is
	# paid inside the claim - so without catching the signal the player just
	# sees a slightly larger number and no reason for it. Listened to only for
	# the duration of the action, so a level earned anywhere else on the board
	# does not surface on this bubble.
	_levelled_to = 0
	AircraftAffinity.model_levelled.connect(_on_model_levelled)

	action.call()

	AircraftAffinity.model_levelled.disconnect(_on_model_levelled)

	var money: int = Economy.money - money_before
	var fuel: int = fuel_before - FuelStore.amount
	var coins: int = Coins.amount - coins_before
	var xp: int = Progression.xp - xp_before
	# Where the numbers come off: the middle of the bubble, at its top.
	var at := position + Vector2(BUBBLE_SIZE.x * 0.5, 0.0)
	var stack := 0.0
	if money > 0:
		_float("+$%s" % FloatingText.grouped(money), FloatingText.COLOR_GAIN, at, stack)
		stack += 1.0
	if xp > 0:
		# Straight after the cash, because they are two halves of one reward -
		# the money you can see in the HUD, the XP is the thing quietly moving
		# the level bar and nothing ever showed it.
		_float("+%s XP" % FloatingText.grouped(xp), FloatingText.COLOR_XP, at, stack)
		stack += 1.0
	if fuel > 0:
		_float("-%s fuel" % FloatingText.grouped(fuel), FloatingText.COLOR_SPEND, at, stack)
		stack += 1.0
	if coins > 0:
		_float("+%d coin" % coins, FloatingText.COLOR_COIN, at, stack)
		stack += 1.0
	# Last, and in its own colour: the cash for it is already inside the "+$"
	# above, so this is here to say WHY that number was bigger.
	if _levelled_to > 0:
		_float("Level %d!" % _levelled_to, FloatingText.COLOR_LEVEL, at, stack)


# Two figures off one bubble - cash then XP, or a rent claim that also dropped a
# coin - are staggered in TIME rather than stacked in space. Stacked, the second
# number sat under the first and read as a fraction of it; one after the other
# reads as what it is, a reward with two parts.
const FLOAT_STAGGER := 0.5

func _float(text: String, color: Color, at: Vector2, index: float) -> void:
	FloatingText.spawn(get_parent(), at, text, color, index * FLOAT_STAGGER)


func _draw() -> void:
	if not visible:
		return
	_draw_pill(BAR_RECT, COLOR_TRACK, BAR_RADIUS)
	var inner := Rect2(BAR_RECT.position + Vector2(BAR_INSET, BAR_INSET),
		Vector2(maxf(0.0, (BAR_RECT.size.x - BAR_INSET * 2.0) * _fill),
			BAR_RECT.size.y - BAR_INSET * 2.0))
	# Below one full cap the pill has no straight section left and would draw
	# wider than the fill it represents, so the first sliver is squared off.
	if inner.size.x > 0.0:
		_draw_pill(inner, _bar_color, minf(BAR_RADIUS - BAR_INSET, inner.size.x * 0.5))


# A rounded rect. Godot's draw_rect has no corner radius, and a StyleBoxFlat per
# frame would allocate one per redraw - this is two circles and a rectangle.
func _draw_pill(r: Rect2, color: Color, radius: float) -> void:
	if radius <= 0.0:
		draw_rect(r, color, true)
		return
	var cy := r.position.y + r.size.y * 0.5
	draw_rect(Rect2(r.position.x + radius, r.position.y,
		maxf(0.0, r.size.x - radius * 2.0), r.size.y), color, true)
	draw_circle(Vector2(r.position.x + radius, cy), radius, color)
	draw_circle(Vector2(r.position.x + r.size.x - radius, cy), radius, color)


# Places the bubble so its TAIL lands on `tail_point`, in the parent's space.
static func place_by_tail(node: Control, tail_point: Vector2) -> void:
	node.position = tail_point - TAIL
