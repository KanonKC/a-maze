extends CharacterBody3D

enum State { PATROL, CHASE, SEARCH }

const PATROL_SPEED    := 2.0
var chase_speed       := 5.5
const DETECT_RANGE    := 12.0
const HEAR_RANGE      := 5.0
const SEARCH_DURATION := 6.0
const CATCH_DIST      := 1.2
const GRAVITY         := 9.8

var state            := State.PATROL
var player: CharacterBody3D

var _last_known_pos  := Vector3.ZERO
var _search_timer    := 0.0
var _patrol_dir      := Vector3.ZERO
var _patrol_timer    := 0.0
var _catch_cooldown  := 0.0

## ─── Player behavior data ────────────────────────────────
const _POS_BUFFER_SIZE := 20
var _visited_positions: Array[Vector3] = []
var _flashlight_uses   := 0
var _favorite_zone     := -1   # 0=inner 1=middle 2=outer; -1=unknown
var _pos_sample_timer  := 0.0
var _last_flashlight_state := false

@export var ambient_sfx: AudioStream
@export var aggro_sfx:   AudioStream

var _aggro_audio: AudioStreamPlayer3D
var _glow: OmniLight3D

func increase_speed() -> void:
	chase_speed = minf(chase_speed * 1.15, 5.5 * 2.0)

func _ready() -> void:
	add_to_group("ghost")
	player = get_tree().get_first_node_in_group("player")
	_pick_patrol_dir()

	# Breathing / ambient loop — quiet, always on
	# (Enable looping on the AudioStream resource in the Inspector)
	var audio := $Audio as AudioStreamPlayer3D
	if audio and ambient_sfx:
		audio.stream    = ambient_sfx
		audio.volume_db = -18.0
		audio.play()

	# One-shot aggro sting node
	_aggro_audio = AudioStreamPlayer3D.new()
	_aggro_audio.name       = "AggroAudio"
	_aggro_audio.volume_db  = -6.0
	add_child(_aggro_audio)

	# Find OmniLight3D added by maze_level._spawn_ghost()
	for child in get_children():
		if child is OmniLight3D:
			_glow = child
			break

	# Flashlight usage tracked by polling in _sample_player_behavior

func is_frozen() -> bool:
	return _player_is_watching() and not _player_flashlight_active()

func _player_flashlight_active() -> bool:
	var on := player.get_flashlight_on()
	return on

func _sample_player_behavior(delta: float) -> void:
	_pos_sample_timer -= delta
	if _pos_sample_timer > 0.0:
		return
	_pos_sample_timer = 1.0   # sample every second

	# Count flashlight toggles by comparing previous state
	var fl_now := player.get_flashlight_on()
	if fl_now != _last_flashlight_state:
		_flashlight_uses += 1
		_last_flashlight_state = fl_now

	var pos := player.global_position
	_visited_positions.append(pos)
	if _visited_positions.size() > _POS_BUFFER_SIZE:
		_visited_positions.pop_front()

	# Determine favorite zone by majority in buffer
	var counts := [0, 0, 0]
	var maze: Node = get_tree().get_first_node_in_group("maze_level")
	if maze and maze.has_method("_zone"):
		for p: Vector3 in _visited_positions:
			var col := int((p.x - maze.ox) / maze.STEP)
			var row := int((p.z - maze.oz) / maze.STEP)
			col = clamp(col, 0, maze.COLS - 1)
			row = clamp(row, 0, maze.ROWS - 1)
			counts[maze._zone(col, row)] += 1
	_favorite_zone = counts.find(counts.max())

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_catch_cooldown = maxf(_catch_cooldown - delta, 0.0)
	_sample_player_behavior(delta)

	# If player is looking at ghost AND flashlight is on → ghost aggroes instead of freezing
	if _player_is_watching():
		if _player_flashlight_active():
			# Flashlight reveals player's position — force Chase
			if state != State.CHASE:
				_enter_chase()
		else:
			# Normal freeze: player stares at ghost without flashlight
			velocity = Vector3.ZERO
			move_and_slide()
			_update_danger()
			_update_glow(delta)
			return

	match state:
		State.PATROL: _do_patrol(delta)
		State.CHASE:  _do_chase(delta)
		State.SEARCH: _do_search(delta)

	_update_danger()
	_update_glow(delta)

	if _catch_cooldown <= 0.0 and global_position.distance_to(player.global_position) < CATCH_DIST:
		_catch_player()

func _catch_player() -> void:
	_catch_cooldown = 3.0
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		gm.on_player_caught()
	state = State.PATROL
	_pick_patrol_dir()

func _player_is_watching() -> bool:
	var cam: Camera3D = player.get_node_or_null("CameraMount/Camera3D")
	if not cam:
		return false
	var dist := global_position.distance_to(player.global_position)
	if dist > 25.0:
		return false
	var to_ghost    := (global_position - cam.global_position).normalized()
	var cam_forward := -cam.global_transform.basis.z
	if cam_forward.dot(to_ghost) < 0.3:
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(
		cam.global_position,
		global_position + Vector3.UP * 0.5
	)
	query.exclude = [self, player]
	return space.intersect_ray(query).is_empty()

func _can_detect_player() -> bool:
	var dist := global_position.distance_to(player.global_position)
	var effective_hear := HEAR_RANGE * (0.5 if player.is_crouching else 1.0)
	if dist <= effective_hear:
		return true
	if dist <= DETECT_RANGE:
		var space := get_world_3d().direct_space_state
		var query := PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 0.5,
			player.global_position
		)
		query.exclude = [self]
		var hit := space.intersect_ray(query)
		return hit.is_empty() or hit.get("collider") == player
	return false

func _enter_chase() -> void:
	state = State.CHASE
	if _aggro_audio and aggro_sfx:
		_aggro_audio.stream = aggro_sfx
		_aggro_audio.play()

func _do_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_pick_patrol_dir()
	_move(_patrol_dir, PATROL_SPEED, delta)
	if get_slide_collision_count() > 0:
		_pick_patrol_dir()
	if _can_detect_player():
		_enter_chase()

func _do_chase(delta: float) -> void:
	var dir := (player.global_position - global_position)
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	_move(dir, chase_speed, delta)
	var look_pos := player.global_position
	look_pos.y = global_position.y
	if look_pos.distance_to(global_position) > 0.1:
		look_at(look_pos, Vector3.UP)
	if not _can_detect_player():
		_last_known_pos = player.global_position
		_search_timer   = SEARCH_DURATION
		state           = State.SEARCH

func _do_search(delta: float) -> void:
	_search_timer -= delta
	var dir := (_last_known_pos - global_position)
	dir.y = 0.0
	if dir.length() > 0.5:
		_move(dir.normalized(), PATROL_SPEED, delta)
	else:
		if not is_on_floor():
			velocity.y -= GRAVITY * delta
		else:
			velocity.y = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
	if _search_timer <= 0.0:
		state = State.PATROL
		_pick_patrol_dir()
	if _can_detect_player():
		_enter_chase()

func _move(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _find_hiding_spot() -> Vector3:
	# Find the position with the most neighbors within 3 units — densest cluster
	var best_pos  := _visited_positions[0]
	var best_count := 0
	for i in _visited_positions.size():
		var count := 0
		for j in _visited_positions.size():
			if i != j and _visited_positions[i].distance_to(_visited_positions[j]) < 3.0:
				count += 1
		if count > best_count:
			best_count = count
			best_pos   = _visited_positions[i]
	return best_pos

func _clues_found() -> int:
	var gm := get_tree().get_first_node_in_group("game_manager")
	return gm.clues_found if gm else 0

func _pick_patrol_dir() -> void:
	_patrol_timer = randf_range(2.0, 5.0)
	var clues := _clues_found()

	# Level 0-1: pure random patrol
	if clues <= 1 or _visited_positions.is_empty():
		var angle := randf() * TAU
		_patrol_dir = Vector3(cos(angle), 0.0, sin(angle))
		return

	# Level 2-3: weighted toward a remembered position
	if clues <= 3:
		var target: Vector3 = _visited_positions[randi_range(0, _visited_positions.size() - 1)]
		var to_target := (target - global_position)
		to_target.y = 0.0
		if to_target.length() > 0.5:
			_patrol_dir = to_target.normalized()
			return
		var angle := randf() * TAU
		_patrol_dir = Vector3(cos(angle), 0.0, sin(angle))
		return

	# Level 4+: go to the densest cluster in the position buffer (true hiding spot)
	var hiding_spot: Vector3 = _find_hiding_spot()
	var to_spot := (hiding_spot - global_position)
	to_spot.y = 0.0
	if to_spot.length() > 0.5:
		_patrol_dir = to_spot.normalized()
	else:
		var angle := randf() * TAU
		_patrol_dir = Vector3(cos(angle), 0.0, sin(angle))


func _update_glow(delta: float) -> void:
	if not _glow:
		return
	var target_color: Color
	var target_energy: float
	match state:
		State.PATROL:
			target_color  = Color(0.6, 0.7, 1.0)
			target_energy = 0.8
		State.SEARCH:
			target_color  = Color(1.0, 0.6, 0.1)
			target_energy = 1.2
		State.CHASE:
			target_color  = Color(1.0, 0.15, 0.1)
			target_energy = sin(Time.get_ticks_msec() * 0.006) * 0.75 + 2.25
	_glow.light_color  = _glow.light_color.lerp(target_color, 5.0 * delta)
	_glow.light_energy = lerpf(_glow.light_energy, target_energy, 5.0 * delta)

func _update_danger() -> void:
	var dist  := global_position.distance_to(player.global_position)
	var level := 0.0
	match state:
		State.CHASE:   level = 1.0
		State.SEARCH:  level = 0.5
		State.PATROL:  level = clampf(1.0 - dist / DETECT_RANGE, 0.0, 0.3)
	player.set_danger_level(level)
