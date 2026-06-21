extends Node

signal clue_collected(count: int, total: int)
signal clue_text_revealed(text: String)
signal exit_unlocked
signal player_caught
signal game_won

const CLUES_NEEDED = 4
const CLUES_TOTAL = 5

var clues_found := 0
var exit_open := false
var checkpoint_position := Vector3.ZERO

var _end_screen: CanvasLayer

@onready var player: CharacterBody3D = $World/Player
@onready var hud = $HUD

func _ready() -> void:
	checkpoint_position = player.global_position
	hud.setup(player, self)
	_end_screen = load("res://scripts/end_screen.gd").new()
	add_child(_end_screen)
	player_caught.connect(_end_screen.show_caught)
	game_won.connect(_end_screen.show_win)

func collect_clue(text: String = "") -> void:
	clues_found += 1
	emit_signal("clue_collected", clues_found, CLUES_TOTAL)
	if text != "":
		emit_signal("clue_text_revealed", text)
	if clues_found >= CLUES_NEEDED and not exit_open:
		exit_open = true
		emit_signal("exit_unlocked")

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
