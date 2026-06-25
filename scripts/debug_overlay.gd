extends Control

# ── Maze constants (mirror from maze_level.gd) ──────────────
const COLS   := 32
const ROWS   := 22
const CELL   := 3.0
const WALL_T := 0.5
const STEP   := CELL + WALL_T
const EXIT_ROW := 11
const DN := 1; const DS := 2; const DE := 4; const DW := 8

# ── Map display ─────────────────────────────────────────────
const MAP_CELL  := 8          # pixels per grid cell on minimap
const MAP_PAD   := 12         # screen padding from corner
const MAP_W     := COLS * MAP_CELL
const MAP_H     := ROWS * MAP_CELL

# ── Colors ──────────────────────────────────────────────────
const C_BG      := Color(0.0,  0.0,  0.0,  0.65)
const C_WALL    := Color(0.55, 0.50, 0.60, 1.0)
const C_FLOOR   := Color(0.10, 0.09, 0.13, 1.0)
const C_PLAYER  := Color(0.20, 0.70, 1.0,  1.0)
const C_GHOST   := Color(1.0,  0.20, 0.15, 1.0)
const C_CLUE    := Color(1.0,  0.90, 0.20, 1.0)
const C_PICKUP  := Color(0.25, 0.85, 1.0,  1.0)
const C_EXIT    := Color(0.20, 1.0,  0.40, 1.0)
const C_ARROW   := Color(0.20, 1.0,  0.40, 0.90)

var _maze: Node3D   # maze_level node
var _player: Node3D
var _ox: float      # world x offset of maze
var _oz: float      # world z offset of maze

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Find nodes (they are ready by the time debug layer is added)
	_maze   = get_tree().get_first_node_in_group("maze_level")
	_player = get_tree().get_first_node_in_group("player")
	if _maze:
		_ox = _maze.ox
		_oz = _maze.oz

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not _maze or not _player:
		return

	var grid: Array = _maze.grid
	var ox := float(MAP_PAD)
	var oy := float(MAP_PAD)

	# ── Background ───────────────────────────────────────────
	draw_rect(Rect2(ox - 4, oy - 4, MAP_W + 8, MAP_H + 8), C_BG)

	# ── Floor cells ──────────────────────────────────────────
	for row in ROWS:
		for col in COLS:
			var rx := ox + col * MAP_CELL
			var ry := oy + row * MAP_CELL
			draw_rect(Rect2(rx, ry, MAP_CELL, MAP_CELL), C_FLOOR)

	# ── Walls (draw south and east walls based on grid) ──────
	var wall_thick := 1.0
	for row in ROWS:
		for col in COLS:
			var idx := row * COLS + col
			var bits: int = grid[idx] if idx < grid.size() else 0
			var rx := ox + col * MAP_CELL
			var ry := oy + row * MAP_CELL
			# East wall
			if not (bits & DE) and col + 1 < COLS:
				draw_rect(Rect2(rx + MAP_CELL - wall_thick, ry, wall_thick * 2, MAP_CELL), C_WALL)
			# South wall
			if not (bits & DS) and row + 1 < ROWS:
				draw_rect(Rect2(rx, ry + MAP_CELL - wall_thick, MAP_CELL, wall_thick * 2), C_WALL)

	# ── Exit marker ──────────────────────────────────────────
	var ex_col := COLS - 1
	var ex_row := EXIT_ROW
	var exit_px := Vector2(ox + (ex_col + 1) * MAP_CELL - 2, oy + ex_row * MAP_CELL + MAP_CELL * 0.5)
	draw_circle(exit_px, 5.0, C_EXIT)

	# ── Clue items ───────────────────────────────────────────
	for node in get_tree().get_nodes_in_group("clue"):
		if is_instance_valid(node):
			var p := _world_to_map(node.global_position, ox, oy)
			draw_circle(p, 3.5, C_CLUE)

	# ── Pickup items ─────────────────────────────────────────
	for node in get_tree().get_nodes_in_group("pickup"):
		if is_instance_valid(node):
			var p := _world_to_map(node.global_position, ox, oy)
			draw_circle(p, 3.0, C_PICKUP)

	# ── Ghost ────────────────────────────────────────────────
	var ghost := get_tree().get_first_node_in_group("ghost")
	if ghost and is_instance_valid(ghost):
		var gp := _world_to_map(ghost.global_position, ox, oy)
		draw_circle(gp, 5.0, C_GHOST)

	# ── Player ───────────────────────────────────────────────
	var pp := _world_to_map(_player.global_position, ox, oy)
	draw_circle(pp, 5.0, C_PLAYER)

	# ── Legend ───────────────────────────────────────────────
	_draw_legend(ox, oy + MAP_H + 10)

	# ── Exit direction arrow (screen center) ─────────────────
	_draw_exit_arrow()

func _world_to_map(world_pos: Vector3, ox_px: float, oy_px: float) -> Vector2:
	var col := (world_pos.x - _ox) / STEP
	var row := (world_pos.z - _oz) / STEP
	return Vector2(ox_px + col * MAP_CELL, oy_px + row * MAP_CELL)

func _draw_legend(lx: float, ly: float) -> void:
	var items := [
		[C_PLAYER, "ผู้เล่น"],
		[C_GHOST,  "ผี"],
		[C_CLUE,   "เบาะแส"],
		[C_PICKUP, "ไอเทม"],
		[C_EXIT,   "ทางออก"],
	]
	var spacing := 80.0
	for i in items.size():
		var col: Color = items[i][0]
		var label: String = items[i][1]
		var cx := lx + i * spacing + 6
		draw_circle(Vector2(cx, ly + 6), 4.0, col)
		draw_string(ThemeDB.fallback_font, Vector2(cx + 8, ly + 11), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw_exit_arrow() -> void:
	if not _player:
		return
	# World position of exit center
	var exit_world := Vector3(
		_ox + COLS * STEP - WALL_T * 0.5 + 1.5,
		1.0,
		_oz + EXIT_ROW * STEP + STEP * 0.5
	)
	var to_exit := exit_world - _player.global_position
	to_exit.y = 0.0
	if to_exit.length() < 0.1:
		return

	# Rotate into player-local space (yaw only)
	var player_yaw := _player.rotation.y
	var angle := atan2(to_exit.x, to_exit.z) - player_yaw + PI
	var dist := to_exit.length()

	var screen_center := get_viewport_rect().size * 0.5
	var arrow_radius := 90.0
	var tip := screen_center + Vector2(sin(angle), -cos(angle)) * arrow_radius

	# Arrow body
	var tail := screen_center + Vector2(sin(angle), -cos(angle)) * (arrow_radius - 22)
	draw_line(tail, tip, C_ARROW, 3.0)

	# Arrowhead
	var perp := Vector2(-cos(angle), -sin(angle))
	draw_colored_polygon(
		PackedVector2Array([
			tip,
			tip - Vector2(sin(angle), -cos(angle)) * 10 + perp * 5,
			tip - Vector2(sin(angle), -cos(angle)) * 10 - perp * 5,
		]),
		C_ARROW
	)

	# Distance label
	draw_string(ThemeDB.fallback_font,
		tip + Vector2(sin(angle), -cos(angle)) * 14,
		"%.0fm" % dist,
		HORIZONTAL_ALIGNMENT_CENTER, -1, 14, C_EXIT)
