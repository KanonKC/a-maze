extends Node

signal clue_collected(count: int, total: int)
signal clue_text_revealed(text: String)
signal checkpoint_saved
signal exit_unlocked
signal player_caught
signal game_won

const CLUES_NEEDED = 4
const CLUES_TOTAL = 5

var clues_found := 0
var exit_open := false
var checkpoint_position := Vector3.ZERO

var _end_screen: CanvasLayer
var _pause_layer: CanvasLayer
var _debug_layer: CanvasLayer

@onready var player: CharacterBody3D = $World/Player
@onready var hud = $HUD

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	checkpoint_position = player.global_position
	hud.setup(player, self)
	_end_screen = load("res://scripts/end_screen.gd").new()
	add_child(_end_screen)
	player_caught.connect(_end_screen.show_caught)
	game_won.connect(_end_screen.show_win)
	_build_pause_menu()
	_build_debug_overlay()
	_build_post_process()

func _build_post_process() -> void:
	var pp = load("res://scripts/post_process.gd").new()
	add_child(pp)

func _build_pause_menu() -> void:
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 20
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var bg := ColorRect.new()
	bg.anchor_left   = 0.0
	bg.anchor_right  = 1.0
	bg.anchor_top    = 0.0
	bg.anchor_bottom = 1.0
	bg.offset_left   = 0
	bg.offset_right  = 0
	bg.offset_top    = 0
	bg.offset_bottom = 0
	bg.color = Color(0.0, 0.0, 0.0, 0.6)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_layer.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.anchor_left   = 0.5
	vbox.anchor_right  = 0.5
	vbox.anchor_top    = 0.5
	vbox.anchor_bottom = 0.5
	vbox.offset_left   = -150
	vbox.offset_right  = 150
	vbox.offset_top    = -80
	vbox.offset_bottom = 80
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 20)
	bg.add_child(vbox)

	var title := Label.new()
	title.text = "หยุดชั่วคราว"
	title.add_theme_font_size_override("font_size", 48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var resume_btn := Button.new()
	resume_btn.text = "ดำเนินการต่อ"
	resume_btn.add_theme_font_size_override("font_size", 32)
	resume_btn.pressed.connect(_resume_game)
	vbox.add_child(resume_btn)

	var menu_btn := Button.new()
	menu_btn.text = "เมนูหลัก"
	menu_btn.add_theme_font_size_override("font_size", 32)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	vbox.add_child(menu_btn)

	_pause_layer.visible = false

func _build_debug_overlay() -> void:
	if not DebugConfig.DEBUG:
		return
	_debug_layer = CanvasLayer.new()
	_debug_layer.layer = 18
	_debug_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_debug_layer)
	var overlay := load("res://scripts/debug_overlay.gd").new()
	_debug_layer.add_child(overlay)
	_debug_layer.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if DebugConfig.DEBUG and event.is_action_pressed("toggle_debug"):
		_debug_layer.visible = not _debug_layer.visible
	if event.is_action_pressed("ui_cancel"):
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()

func _pause_game() -> void:
	get_tree().paused = true
	_pause_layer.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _resume_game() -> void:
	get_tree().paused = false
	_pause_layer.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func collect_clue(text: String = "") -> void:
	clues_found += 1
	if clues_found == 3:
		checkpoint_position = player.global_position
		emit_signal("checkpoint_saved")
	emit_signal("clue_collected", clues_found, CLUES_TOTAL)
	if text != "":
		emit_signal("clue_text_revealed", text)
	var ghost = get_tree().get_first_node_in_group("ghost")
	if ghost and ghost.has_method("increase_speed"):
		ghost.increase_speed()
	_trigger_world_event(clues_found)
	if clues_found >= CLUES_NEEDED and not exit_open:
		exit_open = true
		emit_signal("exit_unlocked")

func _trigger_world_event(clue_count: int) -> void:
	match clue_count:
		1:
			# Clue 1: flashlight flickers briefly — "it knows you found something"
			_flash_flicker_event()
		2:
			# Clue 2: fog thickens suddenly then fades
			_fog_surge_event()
		3:
			# Clue 3: lights cut out for 1.5s
			_lights_out_event(1.5)
		4:
			# Clue 4: prolonged darkness — ghost now knows where you hide
			_lights_out_event(3.0)
		5:
			# Clue 5: exit unlocked — handled by exit_unlocked signal, no extra event

func _flash_flicker_event() -> void:
	# Temporarily spike danger level to trigger flashlight flicker in player.gd
	if player and player.has_method("set_danger_level"):
		player.set_danger_level(1.0)
		await get_tree().create_timer(0.6).timeout
		player.set_danger_level(0.0)

func _fog_surge_event() -> void:
	var maze: Node = get_tree().get_first_node_in_group("maze_level")
	if not maze:
		return
	var env_node = maze.get_node_or_null("WorldEnvironment")
	if not env_node or not env_node.environment:
		return
	var env: Environment = env_node.environment
	var original_density := env.fog_density
	env.fog_density = 0.18
	await get_tree().create_timer(2.0).timeout
	env.fog_density = original_density

func _lights_out_event(duration: float) -> void:
	var maze: Node = get_tree().get_first_node_in_group("maze_level")
	if not maze:
		return
	var env_node = maze.get_node_or_null("WorldEnvironment")
	if not env_node or not env_node.environment:
		return
	var env: Environment = env_node.environment
	var original_energy := env.ambient_light_energy
	env.ambient_light_energy = 0.0
	if player and player.has_method("set_danger_level"):
		player.set_danger_level(0.8)
	await get_tree().create_timer(duration).timeout
	env.ambient_light_energy = original_energy

func set_checkpoint(pos: Vector3) -> void:
	checkpoint_position = pos

func on_player_caught() -> void:
	emit_signal("player_caught")
	await get_tree().create_timer(1.5).timeout
	player.global_position = checkpoint_position
	player.velocity = Vector3.ZERO

func on_player_exit() -> void:
	if exit_open:
		emit_signal("game_won")
