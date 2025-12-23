extends RefCounted
class_name HexGridHighlight

var grid
var material: ShaderMaterial
var selection_indicator: MeshInstance3D
var hover_indicator: MeshInstance3D
var overlay_mesh: Mesh


func _init(owner) -> void:
	grid = owner


func get_material() -> ShaderMaterial:
	return ensure_material()


func ensure_material() -> ShaderMaterial:
	if material != null:
		return material
	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, blend_mix;

uniform vec3 rim_color = vec3(1.0, 1.0, 0.2);
uniform float rim_power = 2.0;
uniform float use_rim = 1.0;
uniform float fill_strength = 0.25;
uniform float rim_min = 0.2;

varying vec4 instance_custom;

void vertex() {
	instance_custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec4 data = instance_custom;
	float strength = data.a;
	if (strength <= 0.0) {
		ALBEDO = vec3(0.0);
		EMISSION = vec3(0.0);
		ALPHA = 0.0;
	} else {
		float rim = 1.0;
		if (use_rim > 0.5) {
			float ndv = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
			rim = mix(rim_min, 1.0, pow(1.0 - ndv, rim_power));
		}
		vec3 glow = data.rgb;
		float alpha = clamp(strength * fill_strength, 0.0, 1.0);
		alpha = max(alpha, rim_min);
		EMISSION = glow * strength * rim;
		ALBEDO = glow;
		ALPHA = alpha;
	}
}
"""
	material = ShaderMaterial.new()
	material.shader = shader
	material.render_priority = 1
	sync_shader_params()
	return material


func sync_shader_params() -> void:
	if material == null:
		return
	material.set_shader_parameter("rim_color", grid.rim_color)
	material.set_shader_parameter("rim_power", grid.rim_power)
	material.set_shader_parameter("use_rim", 1.0 if grid.use_rim_highlight else 0.0)
	material.set_shader_parameter("fill_strength", grid.highlight_fill_strength)
	material.set_shader_parameter("rim_min", grid.highlight_rim_min)


func ensure_mesh_highlight(mesh: Mesh) -> void:
	if mesh == null:
		return
	ensure_material()
	for surface_idx in range(mesh.get_surface_count()):
		var mat: Material = mesh.surface_get_material(surface_idx)
		if mat == null:
			mat = StandardMaterial3D.new()
			mesh.surface_set_material(surface_idx, mat)
		if mat is BaseMaterial3D:
			var base := mat as BaseMaterial3D
			if base.next_pass != material:
				base.next_pass = material


func refresh(axial: Vector2i, selection_axial: Vector2i, hover_axial: Vector2i) -> void:
	if axial.x < 0 or axial.y < 0:
		return
	var is_selected := axial == selection_axial
	var is_hover := axial == hover_axial
	if not is_selected and not is_hover:
		apply_highlight(axial, Color(0.0, 0.0, 0.0, 0.0), 0.0, false)
		return
	var color: Color = grid.selection_color if is_selected else grid.hover_color
	var energy: float = grid.selection_emission_energy if is_selected else grid.hover_emission_energy
	var use_rim: bool = grid.use_rim_highlight
	apply_highlight(axial, color, energy, use_rim)


func update_selection_indicator(axial: Vector2i, color: Color, energy: float) -> void:
	_update_overlay_indicator(selection_indicator, axial, color, energy)


func update_hover_indicator(axial: Vector2i, color: Color, energy: float) -> void:
	_update_overlay_indicator(hover_indicator, axial, color, energy)


func ensure_overlay_indicators() -> void:
	if not grid.use_overlay_highlight:
		return
	if selection_indicator != null and hover_indicator != null:
		return
	overlay_mesh = CylinderMesh.new()
	var mesh := overlay_mesh as CylinderMesh
	mesh.top_radius = grid.hex_radius * grid.overlay_scale
	mesh.bottom_radius = grid.hex_radius * grid.overlay_scale
	mesh.height = grid.overlay_height
	mesh.radial_segments = 6
	mesh.rings = 1

	selection_indicator = MeshInstance3D.new()
	selection_indicator.name = "SelectionOverlay"
	selection_indicator.mesh = overlay_mesh
	selection_indicator.material_override = _build_overlay_material(grid.selection_color)
	selection_indicator.visible = false
	grid.add_child(selection_indicator)

	hover_indicator = MeshInstance3D.new()
	hover_indicator.name = "HoverOverlay"
	hover_indicator.mesh = overlay_mesh
	hover_indicator.material_override = _build_overlay_material(grid.hover_color)
	hover_indicator.visible = false
	grid.add_child(hover_indicator)


func tile_render_info(q: int, r: int) -> Dictionary:
	if grid.use_multimesh:
		if grid.use_tile_meshes:
			var idx: int = r * grid.map_width + q
			if idx < 0 or idx >= grid.tile_instance_map.size():
				return {}
			var entry: Variant = grid.tile_instance_map[idx]
			if entry == null:
				return {}
			var key: String = entry["key"]
			var inst_idx: int = int(entry["index"])
			var inst: MultiMeshInstance3D = grid.multimesh_bucket_instances.get(key, null)
			if inst == null or inst.multimesh == null:
				return {}
			var t: Transform3D = inst.multimesh.get_instance_transform(inst_idx)
			return {"transform": t, "mesh": inst.multimesh.mesh}
		else:
			if grid.multimesh_instance == null or grid.multimesh_instance.multimesh == null:
				return {}
			var idx: int = r * grid.map_width + q
			if idx < 0 or idx >= grid.multimesh_instance.multimesh.instance_count:
				return {}
			var t: Transform3D = grid.multimesh_instance.multimesh.get_instance_transform(idx)
			return {"transform": t, "mesh": grid.multimesh_instance.multimesh.mesh}
	else:
		var idx: int = r * grid.map_width + q
		if idx < 0 or idx >= grid.mesh_instances.size():
			return {}
		var inst: MeshInstance3D = grid.mesh_instances[idx]
		if inst == null or inst.mesh == null:
			return {}
		return {"transform": inst.transform, "mesh": inst.mesh}


func apply_highlight(axial: Vector2i, color: Color, energy: float, use_rim: bool) -> void:
	if grid.use_multimesh:
		_set_multimesh_highlight(axial, color, energy, use_rim)
	else:
		_set_mesh_instance_highlight(axial, color, energy, use_rim)


func _set_multimesh_highlight(axial: Vector2i, color: Color, energy: float, use_rim: bool) -> void:
	ensure_material()
	if material != null:
		material.set_shader_parameter("use_rim", 1.0 if use_rim else 0.0)
		sync_shader_params()
	var data: Color = Color(color.r, color.g, color.b, max(energy, 0.0))
	var idx: int = axial.y * grid.map_width + axial.x
	if grid.use_tile_meshes:
		if idx < 0 or idx >= grid.tile_instance_map.size():
			return
		var entry: Variant = grid.tile_instance_map[idx]
		if entry == null:
			return
		var key: String = entry["key"]
		var inst_idx: int = int(entry["index"])
		var inst: MultiMeshInstance3D = grid.multimesh_bucket_instances.get(key, null)
		if inst and inst.multimesh:
			inst.multimesh.set_instance_custom_data(inst_idx, data)
	else:
		if grid.multimesh_instance and grid.multimesh_instance.multimesh:
			if idx < 0 or idx >= grid.multimesh_instance.multimesh.instance_count:
				return
			grid.multimesh_instance.multimesh.set_instance_custom_data(idx, data)


func _set_mesh_instance_highlight(axial: Vector2i, color: Color, energy: float, use_rim: bool) -> void:
	var idx: int = axial.y * grid.map_width + axial.x
	if idx < 0 or idx >= grid.mesh_instances.size():
		return
	var inst: MeshInstance3D = grid.mesh_instances[idx]
	if inst == null or inst.mesh == null:
		return
	var surface_count := inst.mesh.get_surface_count()
	if energy <= 0.0:
		for surface_idx in range(surface_count):
			inst.set_surface_override_material(surface_idx, null)
		return
	for surface_idx in range(surface_count):
		var src_mat: Material = inst.mesh.surface_get_material(surface_idx)
		var dup := src_mat.duplicate() if src_mat != null else StandardMaterial3D.new()
		_apply_emission(dup, color, energy, use_rim)
		inst.set_surface_override_material(surface_idx, dup)


func _build_overlay_material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.set("emission_energy_multiplier", 1.0)
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _update_overlay_indicator(indicator: MeshInstance3D, axial: Vector2i, color: Color, energy: float) -> void:
	if not grid.use_overlay_highlight:
		if indicator != null:
			indicator.visible = false
		return
	ensure_overlay_indicators()
	if indicator == null:
		return
	if axial.x < 0 or axial.y < 0:
		indicator.visible = false
		return
	var info := tile_render_info(axial.x, axial.y)
	if info.is_empty():
		indicator.visible = false
		return
	var t: Transform3D = info["transform"]
	var mesh: Mesh = info["mesh"]
	var pos := t.origin
	var scale := t.basis.get_scale()
	var top_offset: float = grid._mesh_top_offset(mesh) * scale.y
	var y: float = pos.y + top_offset + grid.overlay_height * 0.5 + grid.overlay_offset
	indicator.transform = Transform3D(grid.hex_basis, Vector3(pos.x, y, pos.z))
	indicator.visible = true
	var mat: Material = indicator.material_override
	if mat is StandardMaterial3D:
		var smat := mat as StandardMaterial3D
		smat.albedo_color = color
		_apply_emission(smat, color, energy, false)


func _apply_emission(mat: Material, color: Color, energy: float, use_rim: bool) -> void:
	if not (mat is StandardMaterial3D):
		return
	var m: StandardMaterial3D = mat
	m.emission_enabled = energy > 0.0
	m.emission = color
	m.set("emission_energy_multiplier", energy)
	if use_rim:
		m.rim_enabled = true
		m.rim = 1.0
		m.set("rim_tint", grid.rim_color)
		m.rim_power = grid.rim_power
	else:
		m.rim_enabled = false
