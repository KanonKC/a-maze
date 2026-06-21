extends CharacterBody3D

enum State { PATROL, CHASE, SEARCH }

const PATROL_SPEED    := 2.0
const CHASE_SPEED     := 5.5
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

@export var ambient_sfx: AudioStream

func _ready() -> void:
	add_to_group("ghost")
	player = get_tree().get_first_node_in_group("player")
	_pick_patrol_dir()
	var audio := $Audio as AudioStreamPlayer3D
	if audio and ambient_sfx:
		audio.stream = ambient_sfx
		audio.play()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		return

	_catch_cooldown = maxf(_catch_cooldown - delta, 0.0)

	if _player_is_watching():
		velocity = Vector3.ZERO
		move_and_slide()
		_update_danger()
		return

	match state:
		State.PATROL: _do_patrol(delta)
		State.CHASE:  _do_chase(delta)
		State.SEARCH: _do_search(delta)

	_update_danger()

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
	if dist <= HEAR_RANGE:
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

func _do_patrol(delta: float) -> void:
	_patrol_timer -= delta
	if _patrol_timer <= 0.0:
		_pick_patrol_dir()
	_move(_patrol_dir, PATROL_SPEED, delta)
	if get_slide_collision_count() > 0:
		_pick_patrol_dir()
	if _can_detect_player():
		state = State.CHASE

func _do_chase(delta: float) -> void:
	var dir := (player.global_position - global_position)
	dir.y = 0.0
	if dir.length() > 0.01:
		dir = dir.normalized()
	_move(dir, CHASE_SPEED, delta)
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
		state = State.CHASE

func _move(dir: Vector3, speed: float, delta: float) -> void:
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func _pick_patrol_dir() -> void:
	var angle     := randf() * TAU
	_patrol_dir   = Vector3(cos(angle), 0.0, sin(angle))
	_patrol_timer = randf_range(2.0, 5.0)

func _update_danger() -> void:
	var dist  := global_position.distance_to(player.global_position)
	var level := 0.0
	match state:
		State.CHASE:   level = 1.0
		State.SEARCH:  level = 0.5
		State.PATROL:  level = clampf(1.0 - dist / DETECT_RANGE, 0.0, 0.3)
	player.set_danger_level(level)
