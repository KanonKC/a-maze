extends Node3D

# ─── Exit light (class var for signal callback) ───────────
var _exit_light: OmniLight3D

@onready var _world_env: WorldEnvironment = $WorldEnvironment

# ─── Grid constants ───────────────────────────────────────
const COLS  := 32
const ROWS  := 22
const CELL  := 3.0     # corridor width (units)
const WALL_T := 0.5    # wall thickness
const STEP  := CELL + WALL_T   # 3.5 units per grid cell
const WALL_H := 3.0

# Layer boundaries (inclusive cell indices)
# Inner (green):  x 12-20, y 8-14
# Middle (orange): x 5-26, y 3-18
# Outer (purple): everything else
const IX0 := 12; const IX1 := 20; const IY0 := 8;  const IY1 := 14
const MX0 := 5;  const MX1 := 26; const MY0 := 3;  const MY1 := 18

# Directions as bitmask
const DN := 1; const DS := 2; const DE := 4; const DW := 8
const OPP  := {1: 2, 2: 1, 4: 8, 8: 4}
const DDELTA := {1: Vector2i(0,-1), 2: Vector2i(0,1), 4: Vector2i(1,0), 8: Vector2i(-1,0)}

# Exit: east boundary at row 11 (center height)
const EXIT_ROW := 11

# grid[y*COLS+x] = bitmask of carved passages
var grid: Array[int] = []
var rng := RandomNumberGenerator.new()

# World-space offset so maze is centered at origin
var ox: float
var oz: float

func _ready() -> void:
	add_to_group("maze_level")
	rng.randomize()
	grid.resize(COLS * ROWS)
	grid.fill(0)
	ox = -COLS * STEP * 0.5
	oz = -ROWS * STEP * 0.5

	# 1. Generate each zone (iterative DFS)
	_gen_zone(16, 11, 0)   # inner: start at center cell
	_gen_zone(5,  3,  1)   # middle: start at top-left corner of middle zone
	_gen_zone(0,  0,  2)   # outer: start at map corner

	# 2. Punch connection holes between zones
	_connect_zones(0, 1, 3)   # 3 holes: inner ↔ middle
	_connect_zones(1, 2, 4)   # 4 holes: middle ↔ outer

	# 3. Carve wide rooms (remove internal walls)
	#    [col, row, w, h]  — clue rooms numbered 1-5
	_carve_room(15, 1,  3, 2)   # Room 1: outer top-center
	_carve_room(28, 5,  2, 3)   # Room 2: outer top-right
	_carve_room(21, 9,  3, 3)   # Room 3: middle-right
	_carve_room(1,  15, 3, 3)   # Room 4: outer bottom-left
	_carve_room(24, 17, 3, 2)   # Room 5: outer bottom-right

	# 4. Open east exit passage
	grid[_idx(COLS - 1, EXIT_ROW)] |= DE

	# 5. Build 3D geometry
	_build_geometry()

	# Enable fog
	if _world_env and _world_env.environment:
		_world_env.environment.fog_enabled = true
		_world_env.environment.fog_density = 0.02
		_world_env.environment.fog_light_color = Color(0.05, 0.03, 0.08)

	# Connect exit_unlocked signal from game_manager
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_signal("exit_unlocked"):
		gm.exit_unlocked.connect(_on_exit_unlocked)

	# 6. Spawn items
	_spawn_items()

	# 7. Spawn ghost in outer zone, far from player start
	_spawn_ghost()

func _cell_center(col: int, row: int) -> Vector3:
	return Vector3(ox + col * STEP + CELL * 0.5, 1.0, oz + row * STEP + CELL * 0.5)

func _spawn_items() -> void:
	var clue_script := load("res://scripts/clue_item.gd")
	var clue_texts := [
		"มันเริ่มมาตั้งแต่คืนที่ไฟดับ...",
		"ได้ยินเสียงหายใจข้างๆ แต่ไม่มีใคร",
		"ทางออกอยู่ทางตะวันออก  อย่าหยุด",
		"มันไม่ชอบแสง... หรือเปล่า?",
		"คนสุดท้ายที่เข้ามาไม่ได้ออกไป",
	]
	var clue_positions := [
		_cell_center(16, 1),   # Room 1: outer top-center
		_cell_center(28, 6),   # Room 2: outer top-right
		_cell_center(22, 10),  # Room 3: middle-right
		_cell_center(2,  16),  # Room 4: outer bottom-left
		_cell_center(25, 17),  # Room 5: outer bottom-right
	]
	for i in 5:
		_make_clue(clue_positions[i], i, clue_texts[i], clue_script)

	var pickup_script := load("res://scripts/pickup_item.gd")

	# ── ชอล์ก ──────────────────────────────────────────────
	# ตำแหน่งจริง: Room 1 (col=15, row=1)
	_make_pickup(_cell_center(16, 2), 0, pickup_script)   # chalk in room 1

	# ── กระจก ───────────────────────────────────────────────
	# ตำแหน่งจริง: Room 3 (col=21, row=9) ชั้นกลาง
	_make_pickup(_cell_center(22, 10), 1, pickup_script)  # mirror in room 3

	# ── DEV: วางใกล้ start ให้ทดสอบได้เลย ──────────────────
	_make_pickup(_cell_center(14, 11), 0, pickup_script)  # chalk ซ้าย start
	_make_pickup(_cell_center(18, 11), 1, pickup_script)  # mirror ขวา start

func _make_clue(pos: Vector3, id: int, text: String, scr: Script) -> void:
	var area := Area3D.new()
	area.set_script(scr)
	area.clue_id   = id
	area.clue_text = text
	area.position  = pos

	var cs := CollisionShape3D.new()
	cs.shape = SphereShape3D.new()
	(cs.shape as SphereShape3D).radius = 0.6
	area.add_child(cs)

	var mi  := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.9, 0.5)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.7, 0.2)
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	area.add_child(mi)

	add_child(area)

func _spawn_ghost() -> void:
	var ghost := CharacterBody3D.new()
	ghost.set_script(load("res://scripts/ghost.gd"))

	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position = Vector3(0, 0.9, 0)
	ghost.add_child(cs)

	var audio := AudioStreamPlayer3D.new()
	audio.name = "Audio"
	audio.max_distance = 30.0
	ghost.add_child(audio)

	# Body mesh: semi-transparent white capsule
	var mi   := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.4
	mesh.height = 1.8
	mi.mesh = mesh
	mi.position = Vector3(0, 0.9, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color         = Color(0.85, 0.92, 1.0, 0.35)
	mat.emission_enabled     = true
	mat.emission             = Color(0.5, 0.6, 1.0)
	mat.emission_energy_multiplier = 0.8
	mat.transparency         = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode           = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = mat
	ghost.add_child(mi)

	# Glow light so the ghost illuminates nearby walls
	var light        := OmniLight3D.new()
	light.position    = Vector3(0, 0.9, 0)
	light.light_color = Color(0.5, 0.6, 1.0)
	light.light_energy = 1.2
	light.omni_range  = 4.0
	ghost.add_child(light)

	# Start far from player (top-right outer zone)
	ghost.position = _cell_center(28, 3)

	add_child(ghost)

func _make_pickup(pos: Vector3, type: int, scr: Script) -> void:
	var area := Area3D.new()
	area.set_script(scr)
	area.item_type = type
	area.position = pos

	var cs := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	cs.shape = shape
	area.add_child(cs)

	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	mi.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	if type == 0:   # chalk = warm yellow
		mat.albedo_color = Color(0.9, 0.85, 0.6)
		mat.emission = Color(0.6, 0.55, 0.3)
	else:           # mirror = cool blue
		mat.albedo_color = Color(0.6, 0.75, 0.95)
		mat.emission = Color(0.3, 0.45, 0.7)
	mat.emission_energy_multiplier = 1.2
	mi.material_override = mat
	area.add_child(mi)

	add_child(area)

# ─── Grid helpers ─────────────────────────────────────────
func _idx(x: int, y: int) -> int:
	return y * COLS + x

func _in_bounds(x: int, y: int) -> bool:
	return x >= 0 and x < COLS and y >= 0 and y < ROWS

func _zone(x: int, y: int) -> int:
	if x >= IX0 and x <= IX1 and y >= IY0 and y <= IY1:
		return 0  # inner
	if x >= MX0 and x <= MX1 and y >= MY0 and y <= MY1:
		return 1  # middle
	return 2      # outer

# ─── Maze generation ──────────────────────────────────────
func _gen_zone(sx: int, sy: int, zone: int) -> void:
	var visited: Array[bool] = []
	visited.resize(COLS * ROWS)
	visited.fill(false)

	var stack: Array[Vector2i] = [Vector2i(sx, sy)]
	visited[_idx(sx, sy)] = true

	while stack.size() > 0:
		var cur: Vector2i = stack[-1]
		var dirs := _shuffled_dirs()
		var moved := false
		for d in dirs:
			var dv: Vector2i = DDELTA[d]
			var nx := cur.x + dv.x
			var ny := cur.y + dv.y
			if not _in_bounds(nx, ny):
				continue
			if _zone(nx, ny) != zone:
				continue
			if visited[_idx(nx, ny)]:
				continue
			grid[_idx(cur.x, cur.y)] |= d
			grid[_idx(nx, ny)] |= OPP[d]
			visited[_idx(nx, ny)] = true
			stack.append(Vector2i(nx, ny))
			moved = true
			break
		if not moved:
			stack.pop_back()

func _shuffled_dirs() -> Array[int]:
	var dirs: Array[int] = [DN, DS, DE, DW]
	for i in range(3, 0, -1):
		var j := rng.randi_range(0, i)
		var t := dirs[i]; dirs[i] = dirs[j]; dirs[j] = t
	return dirs

func _connect_zones(z_a: int, z_b: int, count: int) -> void:
	var pairs: Array = []
	for y in ROWS:
		for x in COLS:
			if _zone(x, y) != z_a:
				continue
			for d in [DN, DS, DE, DW]:
				var dv: Vector2i = DDELTA[d]
				var nx := x + dv.x; var ny := y + dv.y
				if not _in_bounds(nx, ny): continue
				if _zone(nx, ny) != z_b: continue
				pairs.append([x, y, d, nx, ny])
	# shuffle
	for i in range(pairs.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = pairs[i]; pairs[i] = pairs[j]; pairs[j] = t
	for i in range(mini(count, pairs.size())):
		var p = pairs[i]
		grid[_idx(p[0], p[1])] |= p[2]
		grid[_idx(p[3], p[4])] |= OPP[p[2]]

func _carve_room(rx: int, ry: int, rw: int, rh: int) -> void:
	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			if not _in_bounds(x, y): continue
			if x + 1 < rx + rw and _in_bounds(x + 1, y):
				grid[_idx(x, y)]     |= DE
				grid[_idx(x + 1, y)] |= DW
			if y + 1 < ry + rh and _in_bounds(x, y + 1):
				grid[_idx(x, y)]     |= DS
				grid[_idx(x, y + 1)] |= DN

# ─── Geometry ─────────────────────────────────────────────
func _build_geometry() -> void:
	var mats := [
		_mat(Color(0.22, 0.14, 0.13)),   # zone 0 inner: dark red-brown
		_mat(Color(0.17, 0.14, 0.11)),   # zone 1 middle: dark stone
		_mat(Color(0.12, 0.10, 0.16)),   # zone 2 outer: dark purple
	]
	var floor_mat := _mat(Color(0.09, 0.08, 0.09))
	var ceil_mat  := _mat(Color(0.07, 0.06, 0.08))

	var mw := COLS * STEP
	var md := ROWS * STEP

	# Floor & ceiling
	_box(Vector3(0, -0.1, 0),            Vector3(mw + 1, 0.2, md + 1), floor_mat)
	_box(Vector3(0, WALL_H + 0.1, 0),    Vector3(mw + 1, 0.2, md + 1), ceil_mat)

	# Boundary walls
	var east_x := -ox + WALL_T * 0.5
	_box(Vector3(0,       WALL_H * 0.5, oz - WALL_T * 0.5), Vector3(mw + 1, WALL_H, WALL_T), mats[2])
	_box(Vector3(0,       WALL_H * 0.5, -oz + WALL_T * 0.5), Vector3(mw + 1, WALL_H, WALL_T), mats[2])
	_box(Vector3(ox - WALL_T * 0.5, WALL_H * 0.5, 0),       Vector3(WALL_T, WALL_H, md + 1), mats[2])

	# East boundary: split around exit gap
	var exit_z0 := oz + EXIT_ROW * STEP
	var exit_z1 := exit_z0 + STEP
	var top_len := exit_z0 - oz
	var bot_len := (-oz) - exit_z1
	if top_len > 0:
		_box(Vector3(east_x, WALL_H * 0.5, oz + top_len * 0.5), Vector3(WALL_T, WALL_H, top_len), mats[2])
	if bot_len > 0:
		_box(Vector3(east_x, WALL_H * 0.5, exit_z1 + bot_len * 0.5), Vector3(WALL_T, WALL_H, bot_len), mats[2])

	# Interior walls and pillars per cell
	for y in ROWS:
		for x in COLS:
			var cx := ox + x * STEP   # left edge of cell
			var cz := oz + y * STEP   # top edge of cell
			var wall_mat: StandardMaterial3D = mats[_zone(x, y)] as StandardMaterial3D

			# East wall (if no passage to east)
			if x + 1 < COLS and not (grid[_idx(x, y)] & DE):
				_box(
					Vector3(cx + CELL + WALL_T * 0.5, WALL_H * 0.5, cz + CELL * 0.5),
					Vector3(WALL_T, WALL_H, CELL),
					wall_mat
				)

			# South wall (if no passage to south)
			if y + 1 < ROWS and not (grid[_idx(x, y)] & DS):
				_box(
					Vector3(cx + CELL * 0.5, WALL_H * 0.5, cz + CELL + WALL_T * 0.5),
					Vector3(CELL, WALL_H, WALL_T),
					wall_mat
				)

			# Pillar at SE corner (always fill corner)
			if x + 1 < COLS and y + 1 < ROWS:
				_box(
					Vector3(cx + CELL + WALL_T * 0.5, WALL_H * 0.5, cz + CELL + WALL_T * 0.5),
					Vector3(WALL_T, WALL_H, WALL_T),
					wall_mat
				)

	# Exit trigger area (Area3D just outside east wall)
	_place_exit_trigger(east_x + 1.5, exit_z0 + STEP * 0.5)

func _process(delta: float) -> void:
	if _world_env and _world_env.environment:
		var player = get_tree().get_first_node_in_group("player")
		if player and player.has_method("get_danger_level"):
			var d: float = player.get_danger_level()
			_world_env.environment.fog_density = lerp(
				_world_env.environment.fog_density,
				0.02 + d * 0.06,
				5.0 * delta
			)

func _on_exit_unlocked() -> void:
	if _exit_light:
		_exit_light.light_color = Color(0.2, 1.0, 0.4)

func _place_exit_trigger(x: float, z: float) -> void:
	var area := Area3D.new()
	area.position = Vector3(x, 1.0, z)
	area.add_to_group("exit_area")
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.0, 2.0, STEP)
	cs.shape = shape
	area.add_child(cs)
	area.body_entered.connect(func(body):
		if body.is_in_group("player"):
			var gm = get_tree().get_first_node_in_group("game_manager")
			if gm: gm.on_player_exit()
	)
	add_child(area)

	# ── Exit arch geometry ────────────────────────────────────
	var arch_mat := StandardMaterial3D.new()
	arch_mat.albedo_color = Color(0.18, 0.15, 0.22)
	arch_mat.roughness = 1.0

	var pillar_size := Vector3(0.4, 3.0, 0.4)
	var half_gap := STEP * 0.5   # half the exit gap width in Z

	# Left pillar
	var lp := MeshInstance3D.new()
	var lp_mesh := BoxMesh.new()
	lp_mesh.size = pillar_size
	lp.mesh = lp_mesh
	lp.material_override = arch_mat
	lp.position = Vector3(x, WALL_H * 0.5, z - half_gap + 0.2)
	add_child(lp)

	# Right pillar
	var rp := MeshInstance3D.new()
	var rp_mesh := BoxMesh.new()
	rp_mesh.size = pillar_size
	rp.mesh = rp_mesh
	rp.material_override = arch_mat
	rp.position = Vector3(x, WALL_H * 0.5, z + half_gap - 0.2)
	add_child(rp)

	# Lintel (horizontal bar above)
	var lintel := MeshInstance3D.new()
	var lintel_mesh := BoxMesh.new()
	lintel_mesh.size = Vector3(0.4, 0.4, STEP)
	lintel.mesh = lintel_mesh
	lintel.material_override = arch_mat
	lintel.position = Vector3(x, WALL_H - 0.2, z)
	add_child(lintel)

	# Exit OmniLight — red (locked) until exit_unlocked signal
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.2, 0.2)
	light.light_energy = 2.0
	light.omni_range = 6.0
	light.position = Vector3(x, WALL_H * 0.5, z)
	add_child(light)
	_exit_light = light

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m

func _box(pos: Vector3, size: Vector3, mat: StandardMaterial3D) -> void:
	var body := StaticBody3D.new()
	body.position = pos

	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)

	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	body.add_child(mi)

	add_child(body)
