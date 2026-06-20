extends Area3D

enum ItemType { CHALK, MIRROR }
@export var item_type: ItemType = ItemType.CHALK

var _base_y: float

func _ready() -> void:
	_base_y = position.y
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	position.y = _base_y + sin(Time.get_ticks_msec() * 0.001 * 2.0) * 0.15
	rotate_y(delta * 1.5)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group("player"):
		return
	match item_type:
		ItemType.CHALK:
			body.has_chalk = true
			body.chalk_uses = 15
			body.emit_signal("item_picked_up", "chalk")
		ItemType.MIRROR:
			body.has_mirror = true
			body.emit_signal("item_picked_up", "mirror")
	queue_free()
