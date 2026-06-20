extends Node

signal clue_collected(count: int, total: int)
signal exit_unlocked
signal player_caught
signal game_won

const CLUES_NEEDED = 4
const CLUES_TOTAL = 5

var clues_found := 0
var exit_open := false
var checkpoint_position := Vector3.ZERO

@onready var player: CharacterBody3D = $World/Player
@onready var hud = $HUD

func _ready() -> void:
	checkpoint_position = player.global_position
	hud.setup(player, self)

func collect_clue() -> void:
	clues_found += 1
	emit_signal("clue_collected", clues_found, CLUES_TOTAL)
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
