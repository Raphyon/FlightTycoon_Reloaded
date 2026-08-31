extends Control

# The first thing the game shows, and it is doing real work behind the picture.
#
# Main is loaded on a background thread while this is up rather than after it,
# so the wait is the load rather than a picture shown for a fixed time and then
# a pause. On this machine the load finishes well inside MINIMUM_SECONDS and the
# minimum is what you actually see; on a slower one, or once there is audio to
# stream, the picture holds until the scene is genuinely ready.
#
# THE BAR IS NOT DECORATIVE. It reads ResourceLoader's own progress, so it
# stalls where the load stalls. A bar that animates on a timer while the game
# hitches behind it is worse than no bar, because it says the opposite of what
# is happening.
const MAIN_SCENE := "res://scenes/main/Main.tscn"
const BACKDROP := preload("res://assets/login/login_back@ipad.jpg")

# Long enough to register as deliberate, short enough not to be in the way. The
# picture is 1024x768 and most screens are wider, so it is COVERED rather than
# fitted - a 4:3 image letterboxed onto 16:9 reads as a mistake, and cropping
# the top and bottom of a sky loses nothing.
const MINIMUM_SECONDS := 1.1
const FADE_SECONDS := 0.45

# The bar sits low and narrow. It is the only moving thing on the screen, so it
# does not need to be large to be found.
const BAR_WIDTH := 0.34
const BAR_HEIGHT := 6.0
const BAR_BOTTOM := 0.135
const BAR_TRACK := Color(1, 1, 1, 0.18)
const BAR_FILL := Color(1, 0.83, 0.45, 0.95)

var _bar: ColorRect
var _fill: ColorRect
var _elapsed := 0.0
var _done := false


func _ready() -> void:
	var backdrop := TextureRect.new()
	backdrop.texture = BACKDROP
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	_bar = ColorRect.new()
	_bar.color = BAR_TRACK
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)

	_fill = ColorRect.new()
	_fill.color = BAR_FILL
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)

	_layout()
	get_tree().root.size_changed.connect(_layout)

	# NOT DURING A BOT RUN. The bot drives the autoloads and frees whatever
	# scene is current the moment it starts - which is this one, with a
	# background load of Main.tscn still in flight. The loader then finishes
	# against a freed requester and the run ends in "Parse Error ... Main.tscn"
	# and a signal 11, both of which read as a broken scene file. Main.tscn is
	# fine; it was being loaded by nobody.
	if SaveGame.is_bot_run():
		return

	# Threaded, so the picture is on screen for the whole load rather than
	# appearing after it. Sub-threads because Main pulls in a large tree of
	# scenes and textures.
	ResourceLoader.load_threaded_request(MAIN_SCENE, "", true)


func _layout() -> void:
	var view := get_viewport_rect().size
	var w := view.x * BAR_WIDTH
	var y := view.y * (1.0 - BAR_BOTTOM)
	_bar.position = Vector2((view.x - w) * 0.5, y)
	_bar.size = Vector2(w, BAR_HEIGHT)
	_fill.position = _bar.position
	_fill.size = Vector2(0.0, BAR_HEIGHT)


func _process(delta: float) -> void:
	if _done or SaveGame.is_bot_run():
		return
	_elapsed += delta

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(MAIN_SCENE, progress)
	var loaded: float = float(progress[0]) if progress.size() > 0 else 0.0

	# The bar shows whichever is FURTHER BEHIND - the load or the minimum. It
	# would otherwise fill instantly on a fast machine and then sit full while
	# the picture is still up, which reads as a hang.
	var held: float = clampf(_elapsed / MINIMUM_SECONDS, 0.0, 1.0)
	_fill.size.x = _bar.size.x * minf(loaded, held)

	if status == ResourceLoader.THREAD_LOAD_FAILED:
		# A splash that cannot hand over must not be the last thing anybody
		# sees. Godot will report the failure; this at least gets to the game.
		push_error("Splash: could not load %s" % MAIN_SCENE)
		_done = true
		get_tree().change_scene_to_file(MAIN_SCENE)
		return
	if status != ResourceLoader.THREAD_LOAD_LOADED or _elapsed < MINIMUM_SECONDS:
		return

	_done = true
	var scene: PackedScene = ResourceLoader.load_threaded_get(MAIN_SCENE)
	# Faded on a CanvasLayer above the new scene rather than by fading this one
	# out: change_scene_to_packed frees this node immediately, so anything
	# animating on it dies with it and the swap is a hard cut.
	_fade_into(scene)


func _fade_into(scene: PackedScene) -> void:
	# THE TREE IS HELD IN A LOCAL. change_scene_to_packed frees this node, and
	# the rest of this function runs after that await - so get_tree() on self
	# is null from there on. It has to be captured while there still is a self.
	var tree := get_tree()
	var layer := CanvasLayer.new()
	layer.layer = 128
	var cover := ColorRect.new()
	cover.color = Color(0, 0, 0, 0)
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(cover)
	tree.root.add_child(layer)

	var tween := cover.create_tween()
	tween.tween_property(cover, "color:a", 1.0, FADE_SECONDS * 0.5)
	await tween.finished
	tree.change_scene_to_packed(scene)
	# One frame for the new scene to build before it is revealed, or the fade
	# lifts on a half-built airport.
	await tree.process_frame
	var out := cover.create_tween()
	out.tween_property(cover, "color:a", 0.0, FADE_SECONDS)
	await out.finished
	layer.queue_free()
