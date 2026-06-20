extends Area3D

@onready var door_mesh: MeshInstance3D = $DoorMesh
@onready var locked_light: OmniLight3D = $LockedLight
@onready var open_light: OmniLight3D = $OpenLight

var is_open := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm:
		gm.exit_unlocked.connect(_on_exit_unlocked)
	locked_light.visible = true
	open_light.visible = false

func _on_exit_unlocked() -> void:
	is_open = true
	locked_light.visible = false
	open_light.visible = true
	if door_mesh:
		door_mesh.visible = false

func _on_body_entered(body: Node3D) -> void:
	if is_open and body.is_in_group("player"):
		var gm = get_tree().get_first_node_in_group("game_manager")
		if gm:
			gm.on_player_exit()
