extends CanvasLayer

@onready var flashlight_bar:   ProgressBar = $FlashlightBar
@onready var flashlight_label: Label       = $FlashlightLabel
@onready var clue_label:       Label       = $ClueLabel
@onready var message_label:    Label       = $MessageLabel
@onready var chalk_label:      Label       = $ChalkLabel
@onready var compass_needle:   Control     = $Compass/Needle
@onready var compass_panel:    Control     = $Compass
@onready var mirror_frame:     TextureRect = $MirrorFrame
@onready var item_notif:       Label       = $ItemNotif

var player: CharacterBody3D
var _compass_angle := 0.0
var _mirror_texture_set := false

func _ready() -> void:
	message_label.visible = false
	item_notif.visible    = false
	mirror_frame.visible  = false
	chalk_label.text      = ""

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	# Flashlight
	flashlight_bar.value = player.get_flashlight_energy() * 100
	flashlight_bar.modulate.a = 1.0 if player.get_flashlight_on() else 0.4

	# Compass: spin speed based on danger level
	var danger: float = player.get_danger_level()
	var spin_speed: float = lerp(30.0, 600.0, danger)
	_compass_angle += spin_speed * delta
	compass_needle.rotation_degrees = _compass_angle

	# Mirror texture (set once after player ready)
	if not _mirror_texture_set and player.get_mirror_texture() != null:
		mirror_frame.texture = player.get_mirror_texture()
		_mirror_texture_set = true

	# Mirror visibility
	mirror_frame.visible = player.get_mirror_active()

	# Chalk
	if player.has_chalk:
		chalk_label.text = "ชอล์ก: %d" % player.chalk_uses
	else:
		chalk_label.text = ""

func setup(p: CharacterBody3D, gm: Node) -> void:
	player = p
	gm.clue_collected.connect(_on_clue_collected)
	gm.exit_unlocked.connect(_on_exit_unlocked)
	player.item_picked_up.connect(_on_item_picked_up)
	player.chalk_used.connect(func(_n): pass)  # chalk_label updates in _process

func _on_clue_collected(count: int, total: int) -> void:
	clue_label.text = "เบาะแส: %d/%d" % [count, total]
	_show_message("พบเบาะแส!")

func _on_exit_unlocked() -> void:
	_show_message("ทางออกปรากฏแล้ว!")

func _on_item_picked_up(item_name: String) -> void:
	match item_name:
		"chalk":  _show_item_notif("ได้รับ: ชอล์ก  [E] วางเครื่องหมาย")
		"mirror": _show_item_notif("ได้รับ: กระจก  [R] ส่องหลัง")

func _show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	await get_tree().create_timer(2.5).timeout
	message_label.visible = false

func _show_item_notif(text: String) -> void:
	item_notif.text = text
	item_notif.visible = true
	await get_tree().create_timer(3.0).timeout
	item_notif.visible = false
