extends Control

# Fills the dark slot recessed into hud_info_left@ipad.png. The slot sits at
# x 97-197, y 34-55 within that 220x96 panel - measured off the art rather
# than eyeballed - and this node is parented to the panel and placed to
# match, so it follows if the panel ever moves.
#
# The fill tracks progress through the CURRENT level, not total XP, so it
# empties again on every level up: empty at 0%, full slot width at 100%.

const ICON_INSET := 3.0   # px in from the slot's left edge
const LABEL_GAP := 4.0    # px between the icon and the number

# The fill is a NinePatchRect over assets/hud/xp_fill.png - a baked
# #5C84BA -> #6E9EC5 gradient with radius-5 rounded corners matching the
# slot's own rounding, so the caps stay round at any fill width instead of
# square corners poking past the slot art.
@onready var _fill: NinePatchRect = $Fill
@onready var _icon: TextureRect = $Icon
@onready var _label: Label = $Label
# Sits outside this node rather than inside it: XpBar clips its contents so a
# large XP figure can't spill past the slot art, and that clipping would also
# swallow anything positioned below the bar.
@onready var _level_label: Label = get_parent().get_node("LevelLabel")


func _ready() -> void:
	Progression.xp_changed.connect(_refresh)
	Progression.level_changed.connect(_refresh)
	_refresh(0)


func _refresh(_unused: int) -> void:
	var floor_xp := Progression.xp_for_level(Progression.level)
	var span := Progression.xp_for_level(Progression.level + 1) - floor_xp
	var progress := 0.0
	if span > 0:
		progress = clampf(float(Progression.xp - floor_xp) / float(span), 0.0, 1.0)

	_fill.size = Vector2(size.x * progress, size.y)
	_label.text = str(Progression.xp)
	_level_label.text = "Lv. %d" % Progression.level

	# Icon pinned to the left of the slot, number immediately to its right,
	# both sitting on top of the fill.
	_icon.position = Vector2(ICON_INSET, (size.y - _icon.size.y) * 0.5)
	_label.position = Vector2(_icon.position.x + _icon.size.x + LABEL_GAP, 0)
	_label.size = Vector2(size.x - _label.position.x, size.y)
