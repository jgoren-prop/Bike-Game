extends Node3D
class_name LevelEditor

## Main level editor controller
## Manages edit/play mode, coordinates subsystems

enum EditorMode { EDIT, PLAY }
enum EditorTool { PLACE, SELECT }

signal mode_changed(mode: EditorMode)

var _current_mode: EditorMode = EditorMode.EDIT
var _current_tool: EditorTool = EditorTool.PLACE
var _bike_instance: BikeController
var _bike_scene: PackedScene

@onready var _editor_camera: EditorCamera = $EditorCamera
@onready var _placement_system: PlacementSystem = $PlacementSystem
@onready var _selection_system: SelectionSystem = $SelectionSystem
@onready var _level_serializer: LevelSerializer = $LevelSerializer
@onready var _objects_container: Node3D = $ObjectsContainer
@onready var _editor_ui: Control = $EditorUI
@onready var _ground_plane: StaticBody3D = $GroundPlane
@onready var _spawn_indicator: Node3D = $SpawnIndicator
@onready var _grid_overlay: MeshInstance3D = $GridOverlay


func _ready() -> void:
	# Load bike scene for play mode
	_bike_scene = preload("res://scenes/bike/bike.tscn")
	
	# Setup placement system
	_placement_system.setup(_editor_camera, _objects_container)
	_placement_system.set_active(true)
	_placement_system.object_placed.connect(_on_object_placed)
	
	# Setup selection system
	_selection_system.setup(_editor_camera, _placement_system.get_placed_objects())
	_selection_system.set_active(false)  # Start in place mode
	_selection_system.object_deleted.connect(_on_object_deleted)
	_selection_system.tool_changed.connect(_on_transform_tool_changed)
	_selection_system.snap_toggled.connect(_on_snap_toggled)
	
	# Connect UI signals
	if _editor_ui:
		_editor_ui.prefab_selected.connect(_on_prefab_selected)
		_editor_ui.mode_toggle_pressed.connect(_on_mode_toggle)
		_editor_ui.grid_size_changed.connect(_on_grid_size_changed)
		_editor_ui.clear_level_pressed.connect(_on_clear_level)
		_editor_ui.save_pressed.connect(_on_save_pressed)
		_editor_ui.load_pressed.connect(_on_load_pressed)
	
	# Initialize spawn indicator
	_update_spawn_indicator()
	
	# Point camera at spawn
	if _editor_camera and _spawn_indicator:
		_editor_camera.look_at_point(_spawn_indicator.global_position)
	
	# Start in edit mode
	_enter_edit_mode()


func _input(event: InputEvent) -> void:
	# Tab to toggle mode
	if event is InputEventKey and event.keycode == KEY_TAB and event.pressed and not event.echo:
		toggle_mode()
	
	# Escape to return to edit mode from play, or deselect in edit mode
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if _current_mode == EditorMode.PLAY:
			set_mode(EditorMode.EDIT)
		elif _current_tool == EditorTool.SELECT:
			_selection_system.deselect()
	
	# 1/2 keys to switch tools in edit mode
	if _current_mode == EditorMode.EDIT and event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_1:
			set_tool(EditorTool.PLACE)
		elif event.keycode == KEY_2:
			set_tool(EditorTool.SELECT)


func toggle_mode() -> void:
	if _current_mode == EditorMode.EDIT:
		set_mode(EditorMode.PLAY)
	else:
		set_mode(EditorMode.EDIT)


func set_mode(mode: EditorMode) -> void:
	if mode == _current_mode:
		return
	
	_current_mode = mode
	
	match mode:
		EditorMode.EDIT:
			_enter_edit_mode()
		EditorMode.PLAY:
			_enter_play_mode()
	
	mode_changed.emit(mode)


func get_mode() -> EditorMode:
	return _current_mode


func _enter_edit_mode() -> void:
	# Remove bike if exists
	if _bike_instance and is_instance_valid(_bike_instance):
		_bike_instance.queue_free()
		_bike_instance = null
	
	# Enable editor camera
	_editor_camera.current = true
	_editor_camera.set_active(true)
	
	# Enable placement system
	_placement_system.set_active(true)
	
	# Show editor UI
	if _editor_ui:
		_editor_ui.visible = true
		_editor_ui.set_edit_mode_ui()
	
	# Show ground plane and enable collision for editor raycasting
	if _ground_plane:
		_ground_plane.visible = true
		_ground_plane.set_collision_layer_value(1, true)
		_ground_plane.set_collision_mask_value(1, true)
	
	# Show spawn indicator
	if _spawn_indicator:
		_spawn_indicator.visible = true
		_update_spawn_indicator()
	
	# Show grid overlay
	if _grid_overlay:
		_grid_overlay.visible = true
	
	# Release mouse
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _enter_play_mode() -> void:
	# Find spawn point or use default position
	var spawn_pos := Vector3(0, 2, 0)
	for obj in _placement_system.get_placed_objects():
		if obj.name.begins_with("spawn") or obj.get_meta("prefab_path", "").contains("spawn"):
			spawn_pos = obj.global_position + Vector3(0, 1.5, 0)
			break
	
	# Spawn bike
	_bike_instance = _bike_scene.instantiate()
	add_child(_bike_instance)
	_bike_instance.global_position = spawn_pos
	
	# Disable editor camera, bike has its own
	_editor_camera.current = false
	_editor_camera.set_active(false)
	
	# Disable placement system
	_placement_system.set_active(false)
	_placement_system.clear_selection()
	
	# Hide editor UI (but keep mode toggle visible)
	if _editor_ui:
		_editor_ui.set_play_mode_ui()
	
	# Hide ground plane and disable collision in play mode
	if _ground_plane:
		_ground_plane.visible = false
		_ground_plane.set_collision_layer_value(1, false)
		_ground_plane.set_collision_mask_value(1, false)
	
	# Hide spawn indicator
	if _spawn_indicator:
		_spawn_indicator.visible = false
	
	# Hide grid overlay
	if _grid_overlay:
		_grid_overlay.visible = false
	
	# Capture mouse for bike control
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _on_prefab_selected(prefab_path: String) -> void:
	_placement_system.select_prefab(prefab_path)


func _on_mode_toggle() -> void:
	toggle_mode()


func _on_grid_size_changed(size: float) -> void:
	_placement_system.set_grid_size(size)
	# Update the grid overlay shader
	if _grid_overlay and _grid_overlay.get_surface_override_material(0):
		var mat := _grid_overlay.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("grid_size", size)


func _on_clear_level() -> void:
	_placement_system.clear_all_objects()


func _on_save_pressed(level_name: String) -> void:
	if _level_serializer:
		_level_serializer.save_level(level_name, _placement_system.get_placed_objects())


func _on_load_pressed(level_name: String) -> void:
	if _level_serializer:
		# Get a reference to the array that we can modify
		var placed_objects := _placement_system.get_placed_objects()
		_level_serializer.load_level(level_name, _objects_container, placed_objects)
		_selection_system.update_placed_objects(placed_objects)


func get_placement_system() -> PlacementSystem:
	return _placement_system


func get_selection_system() -> SelectionSystem:
	return _selection_system


func _on_object_placed(_object: Node3D, prefab_path: String) -> void:
	# Update selection system's reference to placed objects
	_selection_system.update_placed_objects(_placement_system.get_placed_objects())
	# Update spawn indicator if a spawn point was placed
	if prefab_path.contains("spawn"):
		_update_spawn_indicator()


func _on_object_deleted(_object: Node3D) -> void:
	# Object was deleted via selection system - arrays already updated
	_update_spawn_indicator()


func _on_transform_tool_changed(tool: SelectionSystem.TransformTool) -> void:
	if _editor_ui:
		var tool_names := ["Move", "Rotate", "Scale"]
		_editor_ui.set_transform_tool(tool_names[tool])


func _on_snap_toggled(enabled: bool) -> void:
	if _editor_ui:
		_editor_ui.set_snap_enabled(enabled)


func _update_spawn_indicator() -> void:
	if not _spawn_indicator:
		return
	
	# Find spawn point or use default position
	var spawn_pos := Vector3(0, 0, 0)
	var spawn_rot := 0.0
	var found_spawn := false
	
	for obj in _placement_system.get_placed_objects():
		var prefab_path: String = obj.get_meta("prefab_path", "")
		if prefab_path.contains("spawn"):
			spawn_pos = obj.global_position
			spawn_rot = obj.global_rotation.y
			found_spawn = true
			break
	
	_spawn_indicator.global_position = spawn_pos
	_spawn_indicator.rotation.y = spawn_rot
	
	# Change color based on whether we have a custom spawn point
	var label := _spawn_indicator.get_node_or_null("Label3D") as Label3D
	if label:
		if found_spawn:
			label.text = "SPAWN POINT"
			label.modulate = Color(0.2, 1.0, 0.3, 1.0)
		else:
			label.text = "DEFAULT SPAWN\n(Place a Spawn Point!)"
			label.modulate = Color(1.0, 0.8, 0.2, 1.0)


func set_tool(tool: EditorTool) -> void:
	if tool == _current_tool:
		return
	
	_current_tool = tool
	
	match tool:
		EditorTool.PLACE:
			_placement_system.set_active(true)
			_selection_system.set_active(false)
			if _editor_ui:
				_editor_ui.set_tool_info("Place (1)")
				_editor_ui.set_place_mode(true)
		EditorTool.SELECT:
			_placement_system.set_active(false)
			_placement_system.clear_selection()
			_selection_system.set_active(true)
			_selection_system.update_placed_objects(_placement_system.get_placed_objects())
			if _editor_ui:
				_editor_ui.set_tool_info("Select (2)")
				_editor_ui.set_place_mode(false)


func get_tool() -> EditorTool:
	return _current_tool

