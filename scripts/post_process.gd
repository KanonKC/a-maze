extends CanvasLayer

# Low-resolution horror post-process using SCREEN_TEXTURE
# Adds: pixelation, film grain, chromatic aberration, vignette
# No SubViewport needed — hooks onto rendered frame directly.

func _ready() -> void:
	layer = 50  # above HUD (HUD is ~10), below pause (20)

	var mat := ShaderMaterial.new()
	mat.shader = _build_shader()
	mat.set_shader_parameter("pixel_size", 4.0)
	mat.set_shader_parameter("grain_strength", 0.055)
	mat.set_shader_parameter("aberration_amount", 0.003)
	mat.set_shader_parameter("vignette_strength", 0.5)

	var rect := ColorRect.new()
	rect.anchor_left   = 0.0
	rect.anchor_right  = 1.0
	rect.anchor_top    = 0.0
	rect.anchor_bottom = 1.0
	rect.offset_left   = 0
	rect.offset_right  = 0
	rect.offset_top    = 0
	rect.offset_bottom = 0
	rect.material = mat
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)

func _build_shader() -> Shader:
	var s := Shader.new()
	s.code = """
shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(1.0, 8.0, 0.5) = 4.0;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.055;
uniform float aberration_amount : hint_range(0.0, 0.02) = 0.003;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 screen_size = vec2(textureSize(SCREEN_TEXTURE, 0));

	// Pixelation — snap UV to grid
	vec2 pixelated_uv = floor(SCREEN_UV * screen_size / pixel_size) * pixel_size / screen_size;

	// Chromatic aberration on pixelated UV
	vec2 offset = (pixelated_uv - 0.5) * aberration_amount;
	float r = texture(SCREEN_TEXTURE, pixelated_uv - offset).r;
	float g = texture(SCREEN_TEXTURE, pixelated_uv).g;
	float b = texture(SCREEN_TEXTURE, pixelated_uv + offset).b;
	vec3 col = vec3(r, g, b);

	// Film grain — animated per frame
	float noise = rand(SCREEN_UV + vec2(TIME * 0.13, TIME * 0.07)) * 2.0 - 1.0;
	col += noise * grain_strength;

	// Vignette
	vec2 vig = SCREEN_UV * (1.0 - SCREEN_UV.yx);
	float vignette = pow(vig.x * vig.y * 15.0, vignette_strength);
	col *= vignette;

	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
"""
	return s
