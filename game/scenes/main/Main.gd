extends Node2D


func _ready() -> void:
	print("ft-proto booted")
	# Aprons and world aircraft (including the starting plane) are all
	# spawned by ApronEditor.gd, driven by Fleet's assignment data - see
	# AreaOrigins for the markers and data/apron_layout.json for the cells.
	$Camera2D.position = $ApronEditor.get_occupied_position()
