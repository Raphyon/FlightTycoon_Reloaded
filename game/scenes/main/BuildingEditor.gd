extends Node2D

# Manual placement tool for BUILDING PLOTS - the empty construction sites, not
# the buildings. What gets built on a plot is the player's choice, made in the
# Prop Shop during play (BuildingProgress); this only decides where the sites
# are, which is authored level data.
#
# Same reason as every other editor here: nothing measured exists for these
# positions, and working them out from the art has gone badly.
#
#   G          toggle plot placement mode on/off
#   left click place a new plot where you click
#   right clic select the plot under the cursor (or deselect)
#   X          delete the selected plot
#   1-9        cycle which building the GHOST previews. Nothing is built by
#              doing this - it is there so you can see whether the biggest
#              thing that could go here actually fits before committing the
#              site. The Office is 338px wide against a 229px apron tile, so
#              "does it fit" is a real question.
#   H          hide/show the ghost
#   C          cycle the SELECTED plot's construction-site art. Tarmac plots
#              get the fenced version, grass ones bare machinery - a fenced
#              concrete pad drawn on a forest floor reads as a mistake, and
#              which plot is which is a placement call, not something to guess
#              from coordinates.
#
# Saves immediately to res://data/building_layout.json, per airport.

const GHOST_ALPHA := 0.45

var _click := ClickDrag.new()
var editing := false
var preview_index := 0
var show_ghost := true
var selected := -1

var _plots: Array = []
var _ghost: Sprite2D
var _hud: EditorHud


func _ready() -> void:
	_hud = EditorHud.create(self)
	reload_for_map()


func reload_for_map() -> void:
	_plots = BuildingLayout.load_data()
	selected = -1
	_update_hud()


func _preview_key() -> String:
	var list: Array = BuildingLayout.BUILDINGS
	if preview_index < 0 or preview_index >= list.size():
		return ""
	return str(list[preview_index]["key"])


# _input rather than _unhandled_input, same as CloudEditor: a placement click
# usually lands on an apron or an existing slot, whose Area2D would claim it
# through physics picking before this node saw the event.
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_G:
			editing = !editing
			if not editing:
				selected = -1
			_update_ghost()
			_update_hud()
			_set_slots_pickable(not editing)
			return
		if not editing:
			return
		var list: Array = BuildingLayout.BUILDINGS
		if event.keycode >= KEY_1 and event.keycode <= KEY_9:
			var idx: int = event.keycode - KEY_1
			if idx < list.size():
				preview_index = idx
				_update_ghost()
				_update_hud()
		elif event.keycode == KEY_H:
			show_ghost = not show_ghost
			_update_ghost()
			_update_hud()
		elif event.keycode == KEY_C:
			_cycle_site()
		elif event.keycode == KEY_X:
			_delete_selected()

	if not editing:
		return
	if event is InputEventMouseMotion:
		_update_ghost()
	elif _click.completed(event):
		# Release-click so a left-drag still pans - see ClickDrag.
		_place(get_global_mouse_position())
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_RIGHT:
		# Right-click is safe to swallow: nothing else wants it.
		get_viewport().set_input_as_handled()
		selected = _pick(get_global_mouse_position())
		_update_hud()


func _place(pos: Vector2) -> void:
	# Re-read before writing so this can't blow away plots added since load -
	# the same guard the other editors use.
	_plots = BuildingLayout.load_data()
	var id := BuildingLayout.next_id(_plots)
	_plots.append({"id": id, "x": pos.x, "y": pos.y})
	BuildingLayout.save_data(_plots)
	selected = _plots.size() - 1
	_rebuild_world()
	_update_hud()


func _pick(pos: Vector2) -> int:
	var best := -1
	var best_d := 90.0
	for i in range(_plots.size()):
		var p: Dictionary = _plots[i]
		var d := pos.distance_to(Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
		if d < best_d:
			best_d = d
			best = i
	return best


func _cycle_site() -> void:
	if selected < 0 or selected >= _plots.size():
		return
	_plots = BuildingLayout.load_data()
	if selected >= _plots.size():
		return
	var types: Array = BuildingLayout.site_types()
	var cur := str(_plots[selected].get("site", "buildings"))
	var i := types.find(cur)
	_plots[selected]["site"] = str(types[(i + 1) % types.size()])
	BuildingLayout.save_data(_plots)
	_rebuild_world()
	_update_hud()


func _delete_selected() -> void:
	if selected < 0 or selected >= _plots.size():
		return
	_plots = BuildingLayout.load_data()
	if selected >= _plots.size():
		return
	_plots.remove_at(selected)
	BuildingLayout.save_data(_plots)
	selected = -1
	_rebuild_world()
	_update_hud()


# The world container owns the slots; ask it to redraw rather than duplicating
# the build here.
func _rebuild_world() -> void:
	var holder := get_node_or_null("../Buildings")
	if holder and holder.has_method("rebuild"):
		holder.rebuild()
	_set_slots_pickable(not editing)


# While placing, the slots must not eat clicks - otherwise you can't put a new
# plot down next to an existing one.
func _set_slots_pickable(on: bool) -> void:
	var holder := get_node_or_null("../Buildings")
	if holder == null:
		return
	for child in holder.get_children():
		if child.has_method("set_pickable"):
			child.set_pickable(on)


func _update_ghost() -> void:
	if not editing or not show_ghost:
		if is_instance_valid(_ghost):
			_ghost.queue_free()
			_ghost = null
		return
	if not is_instance_valid(_ghost):
		_ghost = Sprite2D.new()
		_ghost.centered = false
		_ghost.z_index = 100
		add_child(_ghost)
	var path := BuildingLayout.texture_path(_preview_key())
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	_ghost.texture = tex
	_ghost.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
	_ghost.position = get_global_mouse_position()
	_ghost.modulate = Color(1, 1, 1, GHOST_ALPHA)


func _update_hud() -> void:
	if _hud == null:
		return
	if not editing:
		_hud.set_lines(false, [])
		return
	var lines: Array[String] = [
		"BUILDING PLOT EDITOR - %s  (G to exit)" % Maps.display_name(),
		"",
		"Placing empty construction SITES. What gets built on them is",
		"the player's choice in the Prop Shop, not yours.",
		"",
	]
	var list: Array = BuildingLayout.BUILDINGS
	for i in range(list.size()):
		lines.append("%s %d  %s" % [">" if i == preview_index else " ", i + 1, str(list[i]["name"])])
	lines.append("")
	if selected >= 0 and selected < _plots.size():
		var p: Dictionary = _plots[selected]
		lines.append("selected: plot %d at (%d,%d)   site: %s" % [
			int(p.get("id", 0)), roundi(float(p.get("x", 0.0))),
			roundi(float(p.get("y", 0.0))), str(p.get("site", "buildings"))])
	else:
		lines.append("selected: none   (right click a plot)")
	lines.append("")
	var counts := {}
	for e in _plots:
		var t := str(e.get("site", "buildings"))
		counts[t] = int(counts.get(t, 0)) + 1
	var breakdown := []
	for t in BuildingLayout.site_types():
		breakdown.append("%d %s" % [int(counts.get(t, 0)), t])
	lines.append("%d plots (%s)" % [_plots.size(), ", ".join(breakdown)])
	lines.append("click = place  ·  right click = select  ·  C = site art  ·  X = delete  ·  H = ghost %s"
		% ("on" if show_ghost else "off"))
	_hud.set_lines(true, lines)
