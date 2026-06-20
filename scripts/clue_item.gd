extends Area3D

@export var clue_id: int = 0
var collected := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if not collected:
		rotate_y(delta * 1.2)

func _on_body_entered(body: Node3D) -> void:
	if collected:
		return
	if body.is_in_group("player"):
		collected = true
		var gm = get_tree().get_first_node_in_group("game_manager")
		if gm:
			gm.collect_clue()
		queue_free()
