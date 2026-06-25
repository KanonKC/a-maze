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

# Crosshair nodes created in code
var _crosshair_h: ColorRect
var _crosshair_v: ColorRect
var _caught_flash: ColorRect
var _crouch_label: Label

const _CROSSHAIR_DIM  := Color(0.6, 0.6, 0.6, 0.5)
const _CROSSHAIR_HOT  := Color(1.0, 0.15, 0.15, 0.95)

func _ready() -> void:
	message_label.visible = false
	item_notif.visible    = false
	mirror_frame.visible  = false
	chalk_label.text      = ""
	_build_crosshair()
	_build_crouch_label()

func _build_crouch_label() -> void:
	_crouch_label = Label.new()
	_crouch_label.text = "▼ กำลังก้ม"
	_crouch_label.add_theme_font_size_override("font_size", 18)
	_crouch_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7, 0.6))
	_crouch_label.anchor_left   = 0.5
	_crouch_label.anchor_right  = 0.5
	_crouch_label.anchor_top    = 1.0
	_crouch_label.anchor_bottom = 1.0
	_crouch_label.offset_left   = -60
	_crouch_label.offset_right  = 60
	_crouch_label.offset_top    = -70
	_crouch_label.offset_bottom = -50
	_crouch_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_crouch_label.visible = false
	add_child(_crouch_label)

func _build_crosshair() -> void:
	# Horizontal bar
	_crosshair_h = ColorRect.new()
	_crosshair_h.size = Vector2(14, 2)
	_crosshair_h.anchor_left   = 0.5
	_crosshair_h.anchor_right  = 0.5
	_crosshair_h.anchor_top    = 0.5
	_crosshair_h.anchor_bottom = 0.5
	_crosshair_h.offset_left   = -7
	_crosshair_h.offset_right  =  7
	_crosshair_h.offset_top    = -1
	_crosshair_h.offset_bottom =  1
	_crosshair_h.color         = _CROSSHAIR_DIM
	_crosshair_h.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair_h)

	# Vertical bar
	_crosshair_v = ColorRect.new()
	_crosshair_v.size = Vector2(2, 14)
	_crosshair_v.anchor_left   = 0.5
	_crosshair_v.anchor_right  = 0.5
	_crosshair_v.anchor_top    = 0.5
	_crosshair_v.anchor_bottom = 0.5
	_crosshair_v.offset_left   = -1
	_crosshair_v.offset_right  =  1
	_crosshair_v.offset_top    = -7
	_crosshair_v.offset_bottom =  7
	_crosshair_v.color         = _CROSSHAIR_DIM
	_crosshair_v.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair_v)

	# Full-screen red flash overlay for caught event
	_caught_flash = ColorRect.new()
	_caught_flash.anchor_left   = 0.0
	_caught_flash.anchor_right  = 1.0
	_caught_flash.anchor_top    = 0.0
	_caught_flash.anchor_bottom = 1.0
	_caught_flash.offset_left   = 0
	_caught_flash.offset_right  = 0
	_caught_flash.offset_top    = 0
	_caught_flash.offset_bottom = 0
	_caught_flash.color         = Color(1.0, 0.0, 0.0, 0.0)
	_caught_flash.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(_caught_flash)

func flash_caught() -> void:
	if not _caught_flash:
		return
	var tw := create_tween()
	tw.tween_property(_caught_flash, "color:a", 0.8, 0.05)
	tw.tween_property(_caught_flash, "color:a", 0.0, 0.3)

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

	# Crosshair — red/pulse when freezing ghost, dim grey otherwise
	if _crosshair_h and _crosshair_v:
		var freezing: bool = player.is_freezing_ghost()
		var col: Color
		if freezing:
			# Simple pulse using sine wave
			var pulse := (sin(Time.get_ticks_msec() * 0.006) * 0.5 + 0.5)
			col = _CROSSHAIR_DIM.lerp(_CROSSHAIR_HOT, pulse)
		else:
			col = _CROSSHAIR_DIM
		_crosshair_h.color = col
		_crosshair_v.color = col

	# Chalk
	if player.has_chalk:
		chalk_label.text = "ชอล์ก: %d" % player.chalk_uses
	else:
		chalk_label.text = ""

	# Crouch indicator
	if _crouch_label:
		_crouch_label.visible = player.is_crouching

func setup(p: CharacterBody3D, gm: Node) -> void:
	player = p
	gm.clue_collected.connect(_on_clue_collected)
	gm.clue_text_revealed.connect(_show_message)
	gm.checkpoint_saved.connect(func(): _show_message("คุณจำสถานที่นี้ไว้..."))
	gm.exit_unlocked.connect(_on_exit_unlocked)
	gm.player_caught.connect(flash_caught)
	player.item_picked_up.connect(_on_item_picked_up)
	player.chalk_used.connect(func(_n): pass)  # chalk_label updates in _process

func _on_clue_collected(count: int, total: int) -> void:
	clue_label.text = "เบาะแส: %d/%d" % [count, total]
	if count >= total:
		clue_label.modulate = Color(0.2, 1.0, 0.4)
		var tw := create_tween()
		tw.tween_property(clue_label, "scale", Vector2(1.3, 1.3), 0.2)
		tw.tween_property(clue_label, "scale", Vector2(1.0, 1.0), 0.2)
	elif count >= 3:
		clue_label.modulate = Color(1.0, 0.85, 0.2)
	else:
		clue_label.modulate = Color(0.8, 0.8, 0.8)

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
