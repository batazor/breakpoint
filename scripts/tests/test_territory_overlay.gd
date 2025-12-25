extends SceneTree

## Comprehensive tests for Territory Overlay Visualization System
## Tests overlay rendering, faction colors, performance, and toggle functionality

const TerritoryOverlay = preload("res://scripts/hex_grid/territory_overlay.gd")
const FactionTerritorySystem = preload("res://scripts/faction_territory_system.gd")
const FactionSystem = preload("res://scripts/faction_system.gd")
const Faction = preload("res://scripts/faction.gd")

var failures: int = 0
var tests_run: int = 0


func _initialize() -> void:
	print("=== Starting Territory Overlay Visualization Tests ===\n")
	
	# Test groups
	_test_overlay_initialization()
	_test_visibility_toggle()
	_test_faction_color_assignment()
	_test_mesh_generation()
	_test_performance_optimization()
	
	# Summary
	print("\n=== Test Summary ===")
	print("Tests run: %d" % tests_run)
	print("Failures: %d" % failures)
	
	if failures == 0:
		print("✅ All tests passed!")
		quit()
	else:
		push_error("❌ %d tests failed" % failures)
		quit(1)


func _test_overlay_initialization() -> void:
	print("--- Testing Overlay Initialization ---")
	
	var overlay := TerritoryOverlay.new()
	
	# Test 1: Initial visibility is false
	_assert(not overlay.is_overlay_visible(),
		"Initial overlay visibility should be false")
	
	# Test 2: Faction colors dictionary is initialized
	_assert(overlay.faction_colors is Dictionary,
		"Faction colors should be a Dictionary")
	
	# Test 3: Default alpha value is set
	_assert(overlay.overlay_alpha == 0.3,
		"Default overlay alpha should be 0.3")
	
	# Test 4: LOD is enabled by default
	_assert(overlay.enable_lod == true,
		"LOD should be enabled by default")
	
	# Test 5: Update interval is reasonable
	_assert(overlay.update_interval > 0.0 and overlay.update_interval <= 1.0,
		"Update interval should be between 0 and 1 second")
	
	overlay.free()


func _test_visibility_toggle() -> void:
	print("--- Testing Visibility Toggle ---")
	
	var overlay := TerritoryOverlay.new()
	
	# Test 1: Toggle from hidden to visible
	overlay.set_overlay_visible(true)
	_assert(overlay.is_overlay_visible(),
		"Overlay should be visible after set_overlay_visible(true)")
	
	# Test 2: Toggle from visible to hidden
	overlay.set_overlay_visible(false)
	_assert(not overlay.is_overlay_visible(),
		"Overlay should be hidden after set_overlay_visible(false)")
	
	# Test 3: Toggle method
	var initial_state := overlay.is_overlay_visible()
	overlay.toggle_visibility()
	_assert(overlay.is_overlay_visible() != initial_state,
		"toggle_visibility() should change visibility state")
	
	# Test 4: Signal emission
	var signal_received := false
	var signal_value := false
	
	overlay.visibility_toggled.connect(func(is_visible: bool):
		signal_received = true
		signal_value = is_visible
	)
	
	overlay.set_overlay_visible(true)
	_assert(signal_received,
		"visibility_toggled signal should be emitted")
	_assert(signal_value == true,
		"Signal should carry correct visibility value")
	
	overlay.free()


func _test_faction_color_assignment() -> void:
	print("--- Testing Faction Color Assignment ---")
	
	var overlay := TerritoryOverlay.new()
	
	# Test 1: Set custom faction color
	var test_color := Color(1.0, 0.0, 0.5, 0.3)
	overlay.set_faction_color(&"test_faction", test_color)
	
	_assert(overlay.faction_colors.has(&"test_faction"),
		"Faction color should be stored in dictionary")
	_assert(overlay.faction_colors[&"test_faction"] == test_color,
		"Stored faction color should match set color")
	
	# Test 2: Multiple factions with different colors
	var red_faction := Color(1.0, 0.0, 0.0, 0.3)
	var blue_faction := Color(0.0, 0.0, 1.0, 0.3)
	var green_faction := Color(0.0, 1.0, 0.0, 0.3)
	
	overlay.set_faction_color(&"red", red_faction)
	overlay.set_faction_color(&"blue", blue_faction)
	overlay.set_faction_color(&"green", green_faction)
	
	_assert(overlay.faction_colors.size() >= 4,
		"Should store multiple faction colors")
	_assert(overlay.faction_colors[&"red"] == red_faction,
		"Red faction color should be correct")
	_assert(overlay.faction_colors[&"blue"] == blue_faction,
		"Blue faction color should be correct")
	_assert(overlay.faction_colors[&"green"] == green_faction,
		"Green faction color should be correct")
	
	# Test 3: Default color palette
	var faction_system := FactionSystem.new()
	
	# Create test factions
	for i in range(6):
		var faction := Faction.new()
		faction.id = StringName("faction_" + str(i))
		faction_system.factions[faction.id] = faction
	
	overlay._faction_system = faction_system
	overlay._initialize_faction_colors()
	
	_assert(overlay.faction_colors.size() >= 6,
		"Should initialize colors for all factions")
	
	# Verify all colors have correct alpha
	for color in overlay.faction_colors.values():
		_assert(color.a == overlay.overlay_alpha,
			"All faction colors should have correct alpha value")
	
	faction_system.free()
	overlay.free()


func _test_mesh_generation() -> void:
	print("--- Testing Mesh Generation ---")
	
	var overlay := TerritoryOverlay.new()
	overlay._setup_overlay_mesh()
	
	# Test 1: Overlay mesh is created
	_assert(overlay._overlay_mesh != null,
		"Overlay mesh should be created")
	
	# Test 2: Mesh has correct type
	_assert(overlay._overlay_mesh is ArrayMesh,
		"Overlay mesh should be an ArrayMesh")
	
	# Test 3: Mesh has surface data
	var mesh: ArrayMesh = overlay._overlay_mesh
	_assert(mesh.get_surface_count() > 0,
		"Overlay mesh should have at least one surface")
	
	# Test 4: Hexagonal mesh generation
	var hex_mesh := overlay._create_hex_mesh()
	_assert(hex_mesh is ArrayMesh,
		"Created hex mesh should be an ArrayMesh")
	
	# Get vertex data
	var arrays := hex_mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	
	# Hexagon should have 8 vertices (1 center + 7 for ring, with last == first)
	_assert(vertices.size() == 8,
		"Hexagonal mesh should have 8 vertices (1 center + 7 ring)")
	
	# Test 5: Center vertex is at origin
	_assert(vertices[0] == Vector3(0, 0, 0),
		"Center vertex should be at origin")
	
	# Test 6: Has indices for triangulation
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	_assert(indices.size() == 18,  # 6 triangles * 3 vertices
		"Should have 18 indices for 6 triangles")
	
	overlay.free()


func _test_performance_optimization() -> void:
	print("--- Testing Performance Optimization ---")
	
	var overlay := TerritoryOverlay.new()
	
	# Test 1: Update interval prevents excessive updates
	_assert(overlay.update_interval >= 0.1,
		"Update interval should be at least 0.1 seconds to prevent excessive updates")
	
	# Test 2: LOD system is enabled
	_assert(overlay.enable_lod == true,
		"LOD should be enabled for performance")
	
	# Test 3: LOD distances are reasonable
	_assert(overlay.lod_distance_near < overlay.lod_distance_far,
		"Near LOD distance should be less than far LOD distance")
	
	# Test 4: Multimesh batching
	# Create mock territory system with multiple tiles
	var territory_system := FactionTerritorySystem.new()
	var faction_system := FactionSystem.new()
	
	# Create test faction
	var faction := Faction.new()
	faction.id = &"test_faction"
	faction_system.factions[&"test_faction"] = faction
	
	overlay._territory_system = territory_system
	overlay._faction_system = faction_system
	overlay._setup_overlay_mesh()
	overlay._initialize_faction_colors()
	
	# Simulate multiple territory tiles (100 tiles)
	var test_tiles: Array[Vector2i] = []
	for i in range(10):
		for j in range(10):
			test_tiles.append(Vector2i(i, j))
	
	# Create multimesh for faction
	overlay._create_faction_multimesh(&"test_faction", test_tiles)
	
	# Test that multimesh was created
	_assert(overlay._multimesh_instances.has(&"test_faction"),
		"MultiMesh instance should be created for faction")
	
	var instance: MultiMeshInstance3D = overlay._multimesh_instances[&"test_faction"]
	_assert(instance != null and is_instance_valid(instance),
		"MultiMeshInstance3D should be valid")
	_assert(instance.multimesh != null,
		"MultiMesh should be assigned")
	_assert(instance.multimesh.instance_count == 100,
		"MultiMesh should have 100 instances for 100 tiles")
	
	# Test 5: Material settings for performance
	var material: Material = instance.material_override
	_assert(material is StandardMaterial3D,
		"Material should be StandardMaterial3D")
	
	var std_mat := material as StandardMaterial3D
	_assert(std_mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"Material should use alpha transparency")
	_assert(std_mat.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED,
		"Material should be unshaded for performance")
	_assert(std_mat.depth_draw_mode == BaseMaterial3D.DEPTH_DRAW_DISABLED,
		"Depth draw should be disabled for overlay")
	
	# Test 6: Shadow casting disabled
	_assert(instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"Shadow casting should be disabled for performance")
	
	territory_system.free()
	faction_system.free()
	overlay.free()


func _assert(condition: bool, message: String) -> void:
	tests_run += 1
	if not condition:
		failures += 1
		print("  ❌ FAIL: %s" % message)
	else:
		print("  ✅ PASS: %s" % message)
