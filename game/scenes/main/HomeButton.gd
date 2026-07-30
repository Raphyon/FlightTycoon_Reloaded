extends TextureButton

# Travels straight back to the home airport.
#
# Exists mainly for the robot airport, which deliberately isn't on the world-map
# board - you get there by clicking a plane's "Arrived" bubble, so without this
# there'd be no way back out. It shows on every airport except home rather than
# only the robot: the others are reachable from the board, but a one-click way
# home is no worse there, and a button that appears on exactly one map reads as
# a quirk rather than a rule.


func _ready() -> void:
	pressed.connect(func() -> void: Maps.travel_to(Maps.DEFAULT_MAP))
	Maps.map_changed.connect(func(_k: String) -> void: _refresh())
	_refresh()


func _refresh() -> void:
	visible = Maps.current != Maps.DEFAULT_MAP
