extends CharacterBody3D

# ── Movement ───────────────────────────────────────────────
const WALK_SPEED    := 4.0
const CROUCH_SPEED  := 1.8
const MOUSE_SENS    := 0.002
const GRAVITY       := 9.8
const STAND_H       := 1.8
const CROUCH_H      := 0.9
const CROUCH_LERP   := 10.0

# ── Flashlight ─────────────────────────────────────────────
var flashlight_on     := false
var flashlight_energy := 1.0
const FL_DRAIN := 0.004
const FL_MIN   := 0.05

# ── Inventory ──────────────────────────────────────────────
var has_chalk  := false
var chalk_uses := 15
var has_mirror := false

# ── Internal ───────────────────────────────────────────────
var is_crouching := false
var _step_timer  := 0.0
var _danger_level := 0.0   # 0 = safe, 1 = ghost very close (set by ghost AI)

var _mirror_viewport: SubViewport
var _mirror_cam: Camera3D
var _mirror_active := false

# ── Signals ────────────────────────────────────────────────
signal item_picked_up(item_name: String)
signal chalk_used(remaining: int)
signal danger_changed(level: float)

@onready var camera:       Camera3D           = $CameraMount/Camera3D
@onready var camera_mount: Node3D             = $CameraMount
@onready var col_shape:    CollisionShape3D   = $CollisionShape3D
@onready var flashlight:   SpotLight3D        = $CameraMount/Camera3D/Flashlight
@onready var step_audio:   AudioStreamPlayer3D = $StepAudio

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	flashlight.visible = false
	_setup_mirror()

func _setup_mirror() -> void:
	_mirror_viewport = SubViewport.new()
	_mirror_viewport.size = Vector2(320, 180)
	_mirror_viewport.own_world_3d = false
	_mirror_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(_mirror_viewport)

	_mirror_cam = Camera3D.new()
	_mirror_viewport.add_child(_mirror_cam)

# ── Input ──────────────────────────────────────────────────
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		camera_mount.rotate_x(-event.relative.y * MOUSE_SENS)
		camera_mount.rotation.x = clamp(camera_mount.rotation.x, deg_to_rad(-80), deg_to_rad(80))

	if event.is_action_pressed("toggle_flashlight"):
		_toggle_flashlight()
	if event.is_action_pressed("use_chalk"):
		_try_place_chalk()
	if event.is_action_pressed("use_mirror") and has_mirror:
		_mirror_active = true
		_mirror_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if event.is_action_released("use_mirror"):
		_mirror_active = false
		_mirror_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# ── Per-frame ──────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	_handle_crouch(delta)
	_handle_movement(delta)
	_handle_flashlight(delta)
	_handle_footsteps(delta)
	_sync_mirror_cam()

func _handle_movement(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	var speed := CROUCH_SPEED if is_crouching else WALK_SPEED
	var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	if dir:
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
	move_and_slide()

func _handle_crouch(delta: float) -> void:
	is_crouching = Input.is_action_pressed("crouch")
	var target_h := CROUCH_H if is_crouching else STAND_H
	var shape := col_shape.shape as CapsuleShape3D
	shape.height = lerp(shape.height, target_h, CROUCH_LERP * delta)
	camera_mount.position.y = shape.height * 0.45

func _handle_flashlight(delta: float) -> void:
	if flashlight_on and flashlight_energy > 0:
		flashlight_energy -= FL_DRAIN * delta
		flashlight_energy = maxf(flashlight_energy, 0.0)
		flashlight.light_energy = flashlight_energy * 3.0
		if flashlight_energy <= FL_MIN:
			_toggle_flashlight()

func _toggle_flashlight() -> void:
	flashlight_on = !flashlight_on
	flashlight.visible = flashlight_on and flashlight_energy > FL_MIN

func _handle_footsteps(delta: float) -> void:
	if is_on_floor() and velocity.length() > 0.5:
		_step_timer -= delta
		if _step_timer <= 0:
			_step_timer = 0.55 if is_crouching else 0.4
			if step_audio and step_audio.stream:
				step_audio.play()

func _try_place_chalk() -> void:
	if not has_chalk or chalk_uses <= 0:
		return
	var space := get_world_3d().direct_space_state
	var from := camera.global_position
	var to   := from + (-camera.global_transform.basis.z) * 2.5
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = [self]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return

	var mark := MeshInstance3D.new()
	mark.set_script(load("res://scripts/chalk_mark.gd"))
	get_tree().root.add_child(mark)
	mark.global_position = result["position"] + result["normal"] * 0.02
	mark.look_at(mark.global_position + result["normal"], Vector3.UP)

	chalk_uses -= 1
	emit_signal("chalk_used", chalk_uses)

func _sync_mirror_cam() -> void:
	if not _mirror_active:
		return
	_mirror_cam.global_position = camera.global_position
	_mirror_cam.global_rotation = camera.global_rotation + Vector3(0, PI, 0)

# ── Getters (for HUD) ──────────────────────────────────────
func get_flashlight_on() -> bool:     return flashlight_on
func get_flashlight_energy() -> float: return flashlight_energy
func get_mirror_active() -> bool:     return _mirror_active and has_mirror
func get_mirror_texture() -> ViewportTexture: return _mirror_viewport.get_texture()
func get_danger_level() -> float:     return _danger_level

func set_danger_level(v: float) -> void:
	_danger_level = clampf(v, 0.0, 1.0)
	emit_signal("danger_changed", _danger_level)
