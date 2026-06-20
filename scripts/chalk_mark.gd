extends MeshInstance3D

func _ready() -> void:
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.4, 0.4)
	self.mesh = mesh

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.7)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 0.55, 0.4)
	mat.emission_energy_multiplier = 0.8
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = mat
