extends Node

func _ready() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	# Full-screen dark background
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.06)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	# CenterContainer fills screen and centres its child
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 24)
	center.add_child(vbox)

	var title := Label.new()
	title.text = "A MAZE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	vbox.add_child(title)

	var sub := Label.new()
	sub.text = "หาทางออก อย่าให้มันจับได้"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 24)
	sub.modulate = Color(0.6, 0.55, 0.65)
	vbox.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 32)
	vbox.add_child(spacer)

	var btn := Button.new()
	btn.text = "เริ่มเล่น"
	btn.add_theme_font_size_override("font_size", 32)
	btn.custom_minimum_size = Vector2(220, 60)
	vbox.add_child(btn)

	btn.pressed.connect(_on_start_pressed)

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
