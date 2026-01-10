extends Node
class_name SelectionSystem

## Unreal Engine-style selection and transform system
## W = Move, E = Rotate, R = Scale
## Click and drag to transform

signal object_selected(object: Node3D)
signal object_deselected
signal object_deleted(object: Node3D)
signal object_transformed(object: Node3D)
signal tool_changed(tool: TransformTool)
signal snap_toggled(enabled: bool)

enum TransformTool { MOVE, ROTATE, SCALE }

@export var move_sensitivity: float = 0.05
@export var rotate_sensitivity: float = 0.5
@export var scale_sensitivity: float = 0.01

# Snap settings
var snap_enabled: bool = true
var snap_move: float = 1.0  # Units
var snap_rotate: float = 15.0  # Degrees
var snap_scale: float = 0.25  # Scale units

var _camera: Camera3D
var _selected_object: Node3D
var _active: bool = false
var _placed_objects: Array[Node3D]

var _current_tool: TransformTool = TransformTool.MOVE
var _is_dragging: bool = false
var _drag_start_pos: Vector2
var _initial_transform: Transform3D
var _initial_scale: Vector3
var _active_axis: String = ""  # "", "x", "y", "z", or "uniform"
var _hovered_axis: String = ""  # Currently hovered axis

# Visual indicators
var _outline_meshes: Array[MeshInstance3D] = []
var _outline_material: StandardMaterial3D
var _gizmo: Node3D
var _gizmo_arrows: Dictionary = {}  # axis name -> Node3D
var _gizmo_collision_areas: Dictionary = {}  # axis name -> Area3D
var _gizmo_materials: Dictionary = {}  # axis name -> StandardMaterial3D (base material)
var _axis_base_colors: Dictionary = {
	"x": Color(1, 0.2, 0.2),
	"y": Color(0.2, 1, 0.2),
	"z": Color(0.2, 0.4, 1),
	"uniform": Color(1, 1, 1)
}


func _ready() -> void:
	# Create glowing outline material
	_outline_material = StandardMaterial3D.new()
	_outline_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_outline_material.albedo_color = Color(1.0, 0.9, 0.2, 1.0)
	_outline_material.emission_enabled = true
	_outline_material.emission = Color(1.0, 0.8, 0.0)
	_outline_material.emission_energy_multiplier = 2.0
	
	# Create gizmo
	_gizmo = Node3D.new()
	_gizmo.visible = false
	add_child(_gizmo)
	_create_gizmo()


func _create_gizmo() -> void:
	# Clear existing
	for child in _gizmo.get_children():
		child.queue_free()
	_gizmo_arrows.clear()
	_gizmo_collision_areas.clear()
	_gizmo_materials.clear()
	
	match _current_tool:
		TransformTool.MOVE:
			_create_move_gizmo()
		TransformTool.ROTATE:
			_create_rotate_gizmo()
		TransformTool.SCALE:
			_create_scale_gizmo()


func _update_axis_highlight(axis: String, is_hovered: bool, is_active: bool) -> void:
	if not _gizmo_materials.has(axis):
		return
	
	var mat: StandardMaterial3D = _gizmo_materials[axis]
	var base_color: Color = _axis_base_colors.get(axis, Color.WHITE)
	
	if is_active:
		# Brightest when actively dragging
		mat.albedo_color = base_color.lightened(0.5)
		mat.emission = base_color.lightened(0.3)
		mat.emission_energy_multiplier = 4.0
	elif is_hovered:
		# Brighter when hovered
		mat.albedo_color = base_color.lightened(0.3)
		mat.emission = base_color.lightened(0.2)
		mat.emission_energy_multiplier = 3.0
	else:
		# Normal state
		mat.albedo_color = base_color
		mat.emission = base_color
		mat.emission_energy_multiplier = 2.0


func _update_all_axis_highlights() -> void:
	for axis: String in _gizmo_materials.keys():
		var is_hovered: bool = (axis == _hovered_axis)
		var is_active: bool = (axis == _active_axis and _is_dragging)
		_update_axis_highlight(axis, is_hovered, is_active)


func _create_move_gizmo() -> void:
	var arrow_length := 3.0
	var arrow_thickness := 0.1
	
	# X axis - Red arrow
	var x_arrow := _create_arrow_with_collision(Color(1, 0.2, 0.2), arrow_length, arrow_thickness, "x")
	x_arrow.rotation.z = -PI / 2
	_gizmo.add_child(x_arrow)
	_gizmo_arrows["x"] = x_arrow
	
	# Y axis - Green arrow
	var y_arrow := _create_arrow_with_collision(Color(0.2, 1, 0.2), arrow_length, arrow_thickness, "y")
	_gizmo.add_child(y_arrow)
	_gizmo_arrows["y"] = y_arrow
	
	# Z axis - Blue arrow
	var z_arrow := _create_arrow_with_collision(Color(0.2, 0.4, 1), arrow_length, arrow_thickness, "z")
	z_arrow.rotation.x = PI / 2
	_gizmo.add_child(z_arrow)
	_gizmo_arrows["z"] = z_arrow


func _create_rotate_gizmo() -> void:
	var ring_radius := 2.5
	var ring_thickness := 0.08
	
	# X rotation ring - Red
	var x_ring := _create_ring_with_collision(Color(1, 0.2, 0.2), ring_radius, ring_thickness, "x")
	x_ring.rotation.z = PI / 2
	_gizmo.add_child(x_ring)
	_gizmo_arrows["x"] = x_ring
	
	# Y rotation ring - Green
	var y_ring := _create_ring_with_collision(Color(0.2, 1, 0.2), ring_radius, ring_thickness, "y")
	_gizmo.add_child(y_ring)
	_gizmo_arrows["y"] = y_ring
	
	# Z rotation ring - Blue
	var z_ring := _create_ring_with_collision(Color(0.2, 0.4, 1), ring_radius, ring_thickness, "z")
	z_ring.rotation.x = PI / 2
	_gizmo.add_child(z_ring)
	_gizmo_arrows["z"] = z_ring


func _create_scale_gizmo() -> void:
	var handle_length := 2.5
	var handle_thickness := 0.1
	
	# X axis - Red with cube end
	var x_handle := _create_scale_handle_with_collision(Color(1, 0.2, 0.2), handle_length, handle_thickness, "x")
	x_handle.rotation.z = -PI / 2
	_gizmo.add_child(x_handle)
	_gizmo_arrows["x"] = x_handle
	
	# Y axis - Green with cube end
	var y_handle := _create_scale_handle_with_collision(Color(0.2, 1, 0.2), handle_length, handle_thickness, "y")
	_gizmo.add_child(y_handle)
	_gizmo_arrows["y"] = y_handle
	
	# Z axis - Blue with cube end
	var z_handle := _create_scale_handle_with_collision(Color(0.2, 0.4, 1), handle_length, handle_thickness, "z")
	z_handle.rotation.x = PI / 2
	_gizmo.add_child(z_handle)
	_gizmo_arrows["z"] = z_handle
	
	# Center cube for uniform scale - White
	var center := Node3D.new()
	var center_mesh_inst := MeshInstance3D.new()
	var center_mesh := BoxMesh.new()
	center_mesh.size = Vector3(0.5, 0.5, 0.5)
	center_mesh_inst.mesh = center_mesh
	var center_mat := StandardMaterial3D.new()
	center_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	center_mat.albedo_color = Color(1, 1, 1)
	center_mat.emission_enabled = true
	center_mat.emission = Color(1, 1, 1)
	center_mat.emission_energy_multiplier = 2.0
	center_mesh_inst.material_override = center_mat
	center.add_child(center_mesh_inst)
	_gizmo_materials["uniform"] = center_mat
	
	# Add collision for center
	var area := Area3D.new()
	area.set_meta("axis", "uniform")
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.7, 0.7)
	col.shape = shape
	area.add_child(col)
	center.add_child(area)
	_gizmo_collision_areas["uniform"] = area
	
	_gizmo.add_child(center)
	_gizmo_arrows["uniform"] = center


func _create_arrow(color: Color, length: float, thickness: float) -> Node3D:
	var arrow := Node3D.new()
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	
	# Shaft
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = thickness
	shaft_mesh.bottom_radius = thickness
	shaft_mesh.height = length
	shaft.mesh = shaft_mesh
	shaft.position.y = length / 2
	shaft.material_override = mat
	arrow.add_child(shaft)
	
	# Tip cone
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0
	tip_mesh.bottom_radius = thickness * 4
	tip_mesh.height = length * 0.25
	tip.mesh = tip_mesh
	tip.position.y = length + length * 0.125
	tip.material_override = mat
	arrow.add_child(tip)
	
	return arrow


func _create_arrow_with_collision(color: Color, length: float, thickness: float, axis: String) -> Node3D:
	var arrow := Node3D.new()
	
	# Create shared material for this axis
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	_gizmo_materials[axis] = mat
	
	# Shaft
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = thickness
	shaft_mesh.bottom_radius = thickness
	shaft_mesh.height = length
	shaft.mesh = shaft_mesh
	shaft.position.y = length / 2
	shaft.material_override = mat
	arrow.add_child(shaft)
	
	# Tip cone
	var tip := MeshInstance3D.new()
	var tip_mesh := CylinderMesh.new()
	tip_mesh.top_radius = 0
	tip_mesh.bottom_radius = thickness * 4
	tip_mesh.height = length * 0.25
	tip.mesh = tip_mesh
	tip.position.y = length + length * 0.125
	tip.material_override = mat
	arrow.add_child(tip)
	
	# Add collision area for click detection
	var area := Area3D.new()
	area.set_meta("axis", axis)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = thickness * 5  # Larger hit area
	shape.height = length * 1.4
	col.shape = shape
	col.position.y = length / 2
	area.add_child(col)
	arrow.add_child(area)
	_gizmo_collision_areas[axis] = area
	
	return arrow


func _create_ring(color: Color, radius: float, thickness: float) -> Node3D:
	var ring := Node3D.new()
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	
	# Create ring from torus mesh
	var torus := MeshInstance3D.new()
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = radius - thickness
	torus_mesh.outer_radius = radius + thickness
	torus.mesh = torus_mesh
	torus.material_override = mat
	ring.add_child(torus)
	
	return ring


func _create_ring_with_collision(color: Color, radius: float, thickness: float, axis: String) -> Node3D:
	var ring := Node3D.new()
	
	# Create shared material for this axis
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	_gizmo_materials[axis] = mat
	
	# Create ring from torus mesh
	var torus := MeshInstance3D.new()
	var torus_mesh := TorusMesh.new()
	torus_mesh.inner_radius = radius - thickness
	torus_mesh.outer_radius = radius + thickness
	torus.mesh = torus_mesh
	torus.material_override = mat
	ring.add_child(torus)
	
	# Add collision area - use a torus-shaped approximation with multiple boxes around the ring
	var area := Area3D.new()
	area.set_meta("axis", axis)
	
	# Create collision segments around the ring
	var segments := 12
	for i in segments:
		var angle := (float(i) / segments) * TAU
		var col := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(thickness * 8, thickness * 8, radius * 0.6)
		col.shape = shape
		col.position = Vector3(cos(angle) * radius, 0, sin(angle) * radius)
		col.rotation.y = angle
		area.add_child(col)
	
	ring.add_child(area)
	_gizmo_collision_areas[axis] = area
	
	return ring


func _create_scale_handle(color: Color, length: float, thickness: float) -> Node3D:
	var handle := Node3D.new()
	
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	
	# Shaft
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = thickness
	shaft_mesh.bottom_radius = thickness
	shaft_mesh.height = length
	shaft.mesh = shaft_mesh
	shaft.position.y = length / 2
	shaft.material_override = mat
	handle.add_child(shaft)
	
	# Cube end
	var cube := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(thickness * 5, thickness * 5, thickness * 5)
	cube.mesh = cube_mesh
	cube.position.y = length
	cube.material_override = mat
	handle.add_child(cube)
	
	return handle


func _create_scale_handle_with_collision(color: Color, length: float, thickness: float, axis: String) -> Node3D:
	var handle := Node3D.new()
	
	# Create shared material for this axis
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	_gizmo_materials[axis] = mat
	
	# Shaft
	var shaft := MeshInstance3D.new()
	var shaft_mesh := CylinderMesh.new()
	shaft_mesh.top_radius = thickness
	shaft_mesh.bottom_radius = thickness
	shaft_mesh.height = length
	shaft.mesh = shaft_mesh
	shaft.position.y = length / 2
	shaft.material_override = mat
	handle.add_child(shaft)
	
	# Cube end
	var cube := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(thickness * 5, thickness * 5, thickness * 5)
	cube.mesh = cube_mesh
	cube.position.y = length
	cube.material_override = mat
	handle.add_child(cube)
	
	# Add collision area for click detection
	var area := Area3D.new()
	area.set_meta("axis", axis)
	var col := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = thickness * 5
	shape.height = length * 1.3
	col.shape = shape
	col.position.y = length / 2
	area.add_child(col)
	handle.add_child(area)
	_gizmo_collision_areas[axis] = area
	
	return handle


func setup(camera: Camera3D, placed_objects: Array[Node3D]) -> void:
	_camera = camera
	_placed_objects = placed_objects


func set_active(active: bool) -> void:
	_active = active
	if not active:
		deselect()
		_is_dragging = false


func set_snap_enabled(enabled: bool) -> void:
	snap_enabled = enabled


func set_snap_move(size: float) -> void:
	snap_move = size


func set_snap_rotate(degrees: float) -> void:
	snap_rotate = degrees


func set_snap_scale(step: float) -> void:
	snap_scale = step


func is_snap_enabled() -> bool:
	return snap_enabled


func _snap_value(value: float, step: float) -> float:
	if step <= 0:
		return value
	return round(value / step) * step


func _snap_vector(vec: Vector3, step: float) -> Vector3:
	return Vector3(
		_snap_value(vec.x, step),
		_snap_value(vec.y, step),
		_snap_value(vec.z, step)
	)


func update_placed_objects(objects: Array[Node3D]) -> void:
	_placed_objects = objects


func get_selected_object() -> Node3D:
	return _selected_object


func get_current_tool() -> TransformTool:
	return _current_tool


func set_tool(tool: TransformTool) -> void:
	if tool == _current_tool:
		return
	_current_tool = tool
	_create_gizmo()
	_update_gizmo()
	tool_changed.emit(tool)


func select_object(object: Node3D) -> void:
	if _selected_object == object:
		return
	
	deselect()
	_selected_object = object
	_create_outline_for_object(object)
	_update_gizmo()
	object_selected.emit(object)


func deselect() -> void:
	if _selected_object:
		_selected_object = null
		_clear_outline()
		_gizmo.visible = false
		_is_dragging = false
		object_deselected.emit()


func delete_selected() -> void:
	if not _selected_object:
		return
	
	var obj := _selected_object
	_placed_objects.erase(obj)
	deselect()
	object_deleted.emit(obj)
	obj.queue_free()


func _create_outline_for_object(object: Node3D) -> void:
	_clear_outline()
	_create_outline_recursive(object)


func _create_outline_recursive(node: Node) -> void:
	if node is MeshInstance3D:
		var mesh_inst := node as MeshInstance3D
		if mesh_inst.mesh:
			var outline := MeshInstance3D.new()
			outline.mesh = mesh_inst.mesh
			outline.material_override = _outline_material
			outline.global_transform = mesh_inst.global_transform
			outline.scale *= 1.02
			add_child(outline)
			_outline_meshes.append(outline)
	
	for child in node.get_children():
		_create_outline_recursive(child)


func _clear_outline() -> void:
	for mesh in _outline_meshes:
		if is_instance_valid(mesh):
			mesh.queue_free()
	_outline_meshes.clear()


func _update_gizmo() -> void:
	if not _selected_object:
		_gizmo.visible = false
		return
	
	_gizmo.global_position = _selected_object.global_position
	# Don't inherit object rotation for gizmo - keep world-aligned
	_gizmo.global_rotation = Vector3.ZERO
	_gizmo.visible = true


func _input(event: InputEvent) -> void:
	if not _active:
		return
	
	# Tool switching with W, E, R and snap toggle with G
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_W:
				set_tool(TransformTool.MOVE)
			KEY_E:
				set_tool(TransformTool.ROTATE)
			KEY_R:
				set_tool(TransformTool.SCALE)
			KEY_G:
				snap_enabled = not snap_enabled
				snap_toggled.emit(snap_enabled)
			KEY_DELETE, KEY_BACKSPACE:
				delete_selected()
			KEY_ESCAPE:
				if _is_dragging:
					_cancel_drag()
				else:
					deselect()
	
	# Mouse handling
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
					if not _is_mouse_over_ui():
						if _selected_object:
							# Try to click on gizmo axis first
							var clicked_axis := _get_clicked_gizmo_axis()
							if not clicked_axis.is_empty():
								_start_drag(event.position, clicked_axis)
							else:
								# Try to select a different object
								_try_select_at_mouse()
						else:
							_try_select_at_mouse()
			else:
				if _is_dragging:
					_end_drag()
	
	# Drag movement - don't require mouse capture, just track motion
	if event is InputEventMouseMotion and _is_dragging:
		_update_drag(event.position, event.relative)


func _is_mouse_over_ui() -> bool:
	var mouse_pos := get_viewport().get_mouse_position()
	return _check_control_under_mouse(get_tree().root, mouse_pos)


func _check_control_under_mouse(node: Node, mouse_pos: Vector2) -> bool:
	if node is Control:
		var control := node as Control
		if control.visible and control.get_global_rect().has_point(mouse_pos):
			if control is Button or control is ItemList or control is OptionButton or control is PanelContainer:
				return true
	for child in node.get_children():
		if _check_control_under_mouse(child, mouse_pos):
			return true
	return false


func _get_clicked_gizmo_axis() -> String:
	if not _camera or not _gizmo.visible:
		return ""
	
	var mouse_pos := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse_pos)
	var to := from + _camera.project_ray_normal(mouse_pos) * 100.0
	
	var space_state := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit: Object = result.collider
		if hit is Area3D and hit.has_meta("axis"):
			return hit.get_meta("axis")
	
	return ""


func _start_drag(pos: Vector2, axis: String) -> void:
	if not _selected_object:
		return
	
	_is_dragging = true
	_drag_start_pos = pos
	_active_axis = axis
	_initial_transform = _selected_object.global_transform
	_initial_scale = _selected_object.scale
	
	# Update highlights to show active state
	_update_all_axis_highlights()
	
	# DON'T capture mouse - let user see cursor and not move camera


func _update_drag(_pos: Vector2, relative: Vector2) -> void:
	if not _selected_object or not _is_dragging:
		return
	
	var shift_held := Input.is_key_pressed(KEY_SHIFT)
	var sensitivity_mult := 0.25 if shift_held else 1.0
	
	match _current_tool:
		TransformTool.MOVE:
			_apply_move(relative, sensitivity_mult)
		TransformTool.ROTATE:
			_apply_rotate(relative, sensitivity_mult)
		TransformTool.SCALE:
			_apply_scale(relative, sensitivity_mult)
	
	_update_gizmo()
	_refresh_outline()
	object_transformed.emit(_selected_object)


func _apply_move(relative: Vector2, mult: float) -> void:
	var move := Vector3.ZERO
	var delta := (relative.x - relative.y) * move_sensitivity * mult
	
	match _active_axis:
		"x":
			move.x = delta
		"y":
			move.y = -relative.y * move_sensitivity * mult  # Y uses vertical mouse only
		"z":
			move.z = delta
		_:
			# Default: screen-space movement
			var cam_right := _camera.global_transform.basis.x
			move += cam_right * relative.x * move_sensitivity * mult
			move -= Vector3.UP * relative.y * move_sensitivity * mult
	
	# Smooth movement during drag - snapping applied on release
	_selected_object.global_position += move


func _apply_rotate(relative: Vector2, mult: float) -> void:
	var angle := (relative.x - relative.y) * deg_to_rad(rotate_sensitivity) * mult
	
	match _active_axis:
		"x":
			_selected_object.rotate_x(angle)
		"y":
			_selected_object.rotate_y(-relative.x * deg_to_rad(rotate_sensitivity) * mult)
		"z":
			_selected_object.rotate_z(angle)
		_:
			# Default: Y rotation from horizontal, pitch from vertical
			_selected_object.rotate_y(-relative.x * deg_to_rad(rotate_sensitivity) * mult)
			var cam_right := _camera.global_transform.basis.x
			_selected_object.global_rotate(cam_right, -relative.y * deg_to_rad(rotate_sensitivity) * mult)
	
	# Smooth rotation during drag - snapping applied on release


func _apply_scale(relative: Vector2, mult: float) -> void:
	var scale_delta := (relative.x - relative.y) * scale_sensitivity * mult
	
	match _active_axis:
		"x":
			_selected_object.scale.x = max(0.1, _selected_object.scale.x + scale_delta)
		"y":
			_selected_object.scale.y = max(0.1, _selected_object.scale.y + scale_delta)
		"z":
			_selected_object.scale.z = max(0.1, _selected_object.scale.z + scale_delta)
		"uniform", _:
			# Uniform scale
			var new_scale := _selected_object.scale + Vector3.ONE * scale_delta
			new_scale = new_scale.clamp(Vector3.ONE * 0.1, Vector3.ONE * 20.0)
			_selected_object.scale = new_scale
	
	# Smooth scaling during drag - snapping applied on release


func _end_drag() -> void:
	# Apply snapping on release if enabled
	if snap_enabled and _selected_object:
		_apply_final_snap()
	
	_is_dragging = false
	_active_axis = ""
	_update_all_axis_highlights()
	_refresh_outline()


func _apply_final_snap() -> void:
	if not _selected_object:
		return
	
	# Snap position
	_selected_object.global_position = _snap_vector(_selected_object.global_position, snap_move)
	
	# Snap rotation
	var rot := _selected_object.rotation_degrees
	rot.x = _snap_value(rot.x, snap_rotate)
	rot.y = _snap_value(rot.y, snap_rotate)
	rot.z = _snap_value(rot.z, snap_rotate)
	_selected_object.rotation_degrees = rot
	
	# Snap scale
	var s := _selected_object.scale
	s.x = max(0.1, _snap_value(s.x, snap_scale))
	s.y = max(0.1, _snap_value(s.y, snap_scale))
	s.z = max(0.1, _snap_value(s.z, snap_scale))
	_selected_object.scale = s


func _cancel_drag() -> void:
	if _selected_object and _is_dragging:
		_selected_object.global_transform = _initial_transform
		_selected_object.scale = _initial_scale
		_refresh_outline()
		_update_gizmo()
	_end_drag()


func _refresh_outline() -> void:
	if _selected_object:
		_create_outline_for_object(_selected_object)


func _try_select_at_mouse() -> void:
	if not _camera:
		return
	
	var mouse_pos := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse_pos)
	var to := from + _camera.project_ray_normal(mouse_pos) * 500.0
	
	var space_state := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit_object: Node3D = result.collider
		var placed_obj := _find_placed_parent(hit_object)
		if placed_obj:
			select_object(placed_obj)
		else:
			deselect()
	else:
		deselect()


func _find_placed_parent(node: Node) -> Node3D:
	if not node:
		return null
	if node is Node3D and _placed_objects.has(node):
		return node as Node3D
	if node.get_parent():
		return _find_placed_parent(node.get_parent())
	return null


func _process(_delta: float) -> void:
	if _selected_object and is_instance_valid(_selected_object):
		_update_gizmo()
		
		# Update hover state when not dragging
		if not _is_dragging and _active:
			var new_hovered := _get_hovered_gizmo_axis()
			if new_hovered != _hovered_axis:
				_hovered_axis = new_hovered
				_update_all_axis_highlights()


func _get_hovered_gizmo_axis() -> String:
	if not _camera or not _gizmo.visible:
		return ""
	
	var mouse_pos := get_viewport().get_mouse_position()
	var from := _camera.project_ray_origin(mouse_pos)
	var to := from + _camera.project_ray_normal(mouse_pos) * 100.0
	
	var space_state := _camera.get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	
	var result := space_state.intersect_ray(query)
	
	if result:
		var hit: Object = result.collider
		if hit is Area3D and hit.has_meta("axis"):
			return hit.get_meta("axis")
	
	return ""
