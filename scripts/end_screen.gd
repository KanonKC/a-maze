extends CanvasLayer

var _panel:  ColorRect
var _title:  Label
var _sub:    Label
var _btn:    Button

func _ready() -> void:
	layer = 10

	_panel = ColorRect.new()
	_panel.color = Color(0, 0, 0, 0.85)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 56)
	vbox.add_child(_title)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.add_theme_font_size_override("font_size", 26)
	vbox.add_child(_sub)

	_btn = Button.new()
	_btn.text = "เล่นใหม่"
	_btn.add_theme_font_size_override("font_size", 28)
	_btn.pressed.connect(func(): get_tree().reload_current_scene())
	vbox.add_child(_btn)

	hide()

func show_caught() -> void:
	_title.text  = "ถูกจับ!"
	_sub.text    = "กำลังกลับไปจุดตรวจ..."
	_btn.visible = false
	show()
	await get_tree().create_timer(1.5).timeout
	hide()

func show_win() -> void:
	_title.text  = "หนีออกมาได้!"
	_sub.text    = "คุณรอดจากเขาวงกตได้สำเร็จ"
	_btn.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	show()
