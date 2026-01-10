extends Node
class_name PlacementSystem

## Handles placing prefabs in the level editor
## Raycasts from mouse, shows ghost preview, snaps to grid

signal object_placed(object: Node3D, prefab_path: String)

@export var grid_size: float = 2.0
@export var rotation_snap: float = 45.0  # Degrees

var _camera: Camera3D
var _ghost_instance: Node3D
var _current_prefab_path: String = ""
var _current_rotation: float = 0.0  # Y rotation in degrees
var _current_height_offset: float = 0.0  # Manual height adjustment
var _active: bool = false
var _placed_objects: Array[Node3D] = []
var _objects_container: Node3D

# Materials for ghost preview
var _ghost_material: StandardMaterial3D


func _ready() -> void:
	# Create semi-transparent material for ghost preview
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = Color(0.3, 0.8, 0.3, 0.5)
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


func setup(camera: Camera3D, container: Node3D) -> void:
	_camera = camera
	_objects_container = container


func set_active(active: bool) -> void:
	_active = active
	if not active and _ghost_instance:
		_ghost_instance.queue_free()
		_ghost_instance = null


func select_prefab(prefab_path: String) -> void:
	_current_prefab_path = prefab_path
	_current_rotation = 0.0
	_current_height_offset = 0.0
	_update_ghost()


func clear_selection() -> void:
	_current_prefab_path = ""
	if _ghost_instance:
		_ghost_instance.queue_free()
		_ghost_instance = null


func set_grid_size(size: float) -> void:
	grid_size = size


func get_grid_size() -> float:
	return grid_size


func get_height_offset() -> float:
	return _current_height_offset


func get_placed_objects() -> Array[Node3D]:
	return _placed_objects


func clear_all_objects() -> void:
	for obj in _placed_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	_placed_objects.clear()


func _update_ghost() -> void:
	# Remove existing ghost
	if _ghost_instance:
		_ghost_instance.queue_free()
		_ghost_instance = null
	
	if _current_prefab_path.is_empty():
		return
	
	# Load and instantiate prefab as ghost
	var prefab: PackedScene = load(_current_prefab_path)
	if not prefab:
		push_error("Failed to load prefab: " + _current_prefab_path)
		return
	
	_ghost_instance = prefab.instantiate()
	_objects_container.add_child(_ghost_instance)
	
	# Make it ghostly - disable collisions and apply transparent material
	_make_ghost(_ghost_instance)


func _make_ghost(node: Node3D) -> void:
	# Disable physics on ghost
	if node is RigidBody3D:
		node.freeze = true
	if node is StaticBody3D:
		# Find and disable collision shapes
		for child in node.get_children():
			if child is CollisionShape3D:
				child.disabled = true
	
	# Apply ghost material to meshes
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		for i in mesh_instance.get_surface_override_material_count():
			mesh_instance.set_surface_override_material(i, _ghost_material)
	
	# Also handle CSG nodes
	if node is CSGShape3D:
		node.use_collision = false
		if node.has_method("set_material"):
			node.material = _ghost_material
	
	# Recurse into children
	for child in node.get_children():
		if child is Node3D:
			_make_ghost(child)


func _input(event: InputEvent) -> void:
	if not _active or _current_prefab_path.is_empty():
		return
	
	if event is InputEventKey and event.pressed and not event.echo:
		# Rotation with R/T
		if event.keycode == KEY_R:
			_current_rotation += rotation_snap
			if _current_rotation >= 360:
				_current_rotation -= 360
			if _ghost_instance:
				_ghost_instance.rotation.y = deg_to_rad(_current_rotation)
		elif event.keycode == KEY_T:
			_current_rotation -= rotation_snap
			if _current_rotation < 0:
				_current_rotation += 360
			if _ghost_instance:
				_ghost_instance.rotation.y = deg_to_rad(_current_rotation)
		
		# Height adjustment with Q/E (uses grid size for step)
		elif event.keycode == KEY_E:  # Raise
			_current_height_offset += grid_size
		elif event.keycode == KEY_Q:  # Lower
			_current_height_offset -= grid_size
			if _current_height_offset < 0:
				_current_height_offset = 0  # Don't go below ground
	
	# Place on left click (but not if clicking on UI)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not _is_mouse_over_ui():
			_place_object()
	
	# Cancel with right click or Escape
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		clear_selection()
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		clear_selection()


func _process(_delta: float) -> void:
	if not _active or not _ghost_instance or not _camera:
		return
	
	# Only update position when mouse is visible (not captured for camera movement)
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	
	# Raycast from mouse position
	var mouse_pos := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse_pos)
	var to := from + _camera.project_ray_normal(mouse_pos) * 500.0
	
	var space_state := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.exclude = _get_ghost_rids()
	
	var result := space_state.intersect_ray(query)
	
	var base_pos: Vector3
	if result:
		base_pos = result.position
	else:
		# If no hit, place at a default distance in front of camera
		base_pos = from + _camera.project_ray_normal(mouse_pos) * 20.0
	
	# Get the object's height offset to place it ON the surface, not IN it
	var auto_height_offset := _get_object_height_offset(_ghost_instance)
	var snapped_pos := _snap_to_grid(base_pos)
	# Apply both automatic height offset and manual height adjustment (Q/E)
	snapped_pos.y = base_pos.y + auto_height_offset + _current_height_offset
	_ghost_instance.global_position = snapped_pos


func _is_mouse_over_ui() -> bool:
	# Check if mouse is over any Control node that should block placement
	var mouse_pos := get_viewport().get_mouse_position()
	var viewport := get_viewport()
	
	# Get the GUI focus owner or check what's under the mouse
	var gui_path := viewport.get_path()
	
	# Simple check: if there's a control under the mouse that's visible and accepts input
	var root := get_tree().root
	return _check_control_under_mouse(root, mouse_pos)


func _check_control_under_mouse(node: Node, mouse_pos: Vector2) -> bool:
	if node is Control:
		var control := node as Control
		# Check if mouse is within this control's rect and it's visible
		if control.visible and control.get_global_rect().has_point(mouse_pos):
			# Check if this is an interactive control (buttons, lists, etc.)
			if control is Button or control is ItemList or control is OptionButton or control is PanelContainer:
				return true
	
	# Check children
	for child in node.get_children():
		if _check_control_under_mouse(child, mouse_pos):
			return true
	
	return false


func _get_ghost_rids() -> Array[RID]:
	var rids: Array[RID] = []
	if _ghost_instance:
		_collect_rids(_ghost_instance, rids)
	return rids


func _collect_rids(node: Node, rids: Array[RID]) -> void:
	if node is CollisionObject3D:
		rids.append(node.get_rid())
	for child in node.get_children():
		_collect_rids(child, rids)


func _snap_to_grid(pos: Vector3) -> Vector3:
	if grid_size <= 0:
		return pos
	return Vector3(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size,
		round(pos.z / grid_size) * grid_size
	)


func _get_object_height_offset(node: Node3D) -> float:
	# Calculate how much to offset the object so its bottom sits on the surface
	# We find the lowest point of the object's collision/mesh and offset accordingly
	var min_y := _find_min_y_recursive(node)
	# The offset is the negative of the minimum Y (to bring the bottom to 0)
	return -min_y


func _find_min_y_recursive(node: Node) -> float:
	var min_y := 0.0
	var found_any := false
	
	# Check collision shapes
	if node is CollisionShape3D:
		var col := node as CollisionShape3D
		var shape := col.shape
		if shape:
			var shape_min := _get_shape_min_y(shape)
			var local_min := shape_min + col.position.y
			if not found_any or local_min < min_y:
				min_y = local_min
				found_any = true
	
	# Check meshes
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh:
			var aabb := mesh_inst.mesh.get_aabb()
			var local_min := aabb.position.y + mesh_inst.position.y
			if not found_any or local_min < min_y:
				min_y = local_min
				found_any = true
	
	# Check CSG shapes
	if node is CSGBox3D:
		var box := node as CSGBox3D
		var local_min := -box.size.y / 2.0 + box.position.y
		if not found_any or local_min < min_y:
			min_y = local_min
			found_any = true
	elif node is CSGCylinder3D:
		var cyl := node as CSGCylinder3D
		var local_min := -cyl.height / 2.0 + cyl.position.y
		if not found_any or local_min < min_y:
			min_y = local_min
			found_any = true
	
	# Recurse into children
	for child in node.get_children():
		var child_min := _find_min_y_recursive(child)
		# Adjust for parent position if needed
		if child is Node3D:
			child_min += (child as Node3D).position.y
		if not found_any or child_min < min_y:
			min_y = child_min
			found_any = true
	
	return min_y


func _get_shape_min_y(shape: Shape3D) -> float:
	if shape is BoxShape3D:
		return -shape.size.y / 2.0
	elif shape is CapsuleShape3D:
		return -shape.height / 2.0
	elif shape is CylinderShape3D:
		return -shape.height / 2.0
	elif shape is SphereShape3D:
		return -shape.radius
	# Default to 0 for unknown shapes
	return 0.0


func _place_object() -> void:
	if not _ghost_instance or _current_prefab_path.is_empty():
		return
	
	# Load fresh instance
	var prefab: PackedScene = load(_current_prefab_path)
	if not prefab:
		return
	
	var new_object := prefab.instantiate()
	_objects_container.add_child(new_object)
	
	# Copy transform from ghost
	new_object.global_transform = _ghost_instance.global_transform
	
	# Store reference and emit signal
	_placed_objects.append(new_object)
	object_placed.emit(new_object, _current_prefab_path)
	
	# Store the prefab path on the object for serialization
	new_object.set_meta("prefab_path", _current_prefab_path)

