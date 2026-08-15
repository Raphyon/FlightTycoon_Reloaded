class_name FloatingText
extends Label

# The number that pops off a bubble when its swoop lands - "+$1,240", "-40 fuel".
#
# It rises and fades over about a second and then frees itself. Deliberately a
# sibling of the bubble rather than a child: the bubble hides the instant its
# work is done, and the number has to outlive it.
#
# WHY IT IS NOT PART OF THE BUBBLE. The swoop's own text is a verb - "Claiming",
# "Refueling" - because the bubble is 96 pixels wide and a figure would have to
# be abbreviated to fit. Floating free, it can be any width, so the amount is
# shown in full: $1,240,000 rather than $1.24M.

const RISE := 34.0
const LIFE := 1.1
# Most of the life is spent solid; the fade is the last third, so the number is
# READ rather than glimpsed.
const FADE_AFTER := 0.6

# Smaller than it was, but it keeps its outline: unlike the bubble's caption
# this floats over the world, where the background is whatever happens to be
# under it.
const FONT_SIZE := 14
const OUTLINE_SIZE := 4
const COLOR_GAIN := Color(0.55, 1.0, 0.6)
const COLOR_SPEND := Color(1.0, 0.78, 0.35)
const COLOR_COIN := Color(1.0, 0.88, 0.35)
const COLOR_OUTLINE := Color(0.07, 0.06, 0.04)

var _age := 0.0
var _from := Vector2.ZERO


# `at` is where the text starts, in the parent's space - the caller passes the
# point just above the bubble it came from.
static func spawn(parent: Node, at: Vector2, text: String, color: Color) -> FloatingText:
	if parent == null or not is_instance_valid(parent):
		return null
	var f := FloatingText.new()
	f.text = text
	f._from = at
	f.add_theme_font_size_override("font_size", FONT_SIZE)
	f.add_theme_color_override("font_color", color)
	f.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	f.add_theme_constant_override("outline_size", OUTLINE_SIZE)
	f.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Above every callout, including the one it just left.
	f.z_index = 200
	f.z_as_relative = false
	f.position = at
	parent.add_child(f)
	return f


func _ready() -> void:
	# Centred on the point it was given, which is the middle of the bubble it
	# came off rather than the bubble's left edge.
	await get_tree().process_frame
	size = get_minimum_size()
	position = _from - Vector2(size.x * 0.5, size.y)


# Real frame time, not GameClock - this is an animation the player watches, and
# fast-forward must not collapse it into a frame. Same rule as ProgressBubble.
func _process(delta: float) -> void:
	_age += delta
	var t: float = clampf(_age / LIFE, 0.0, 1.0)
	position.y = _from.y - size.y - RISE * t
	if t > FADE_AFTER:
		modulate.a = 1.0 - (t - FADE_AFTER) / (1.0 - FADE_AFTER)
	if t >= 1.0:
		queue_free()


# 1234567 -> "1,234,567". GDScript has no thousands format.
static func grouped(n: int) -> String:
	var digits := str(absi(n))
	var out := ""
	var c := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out
