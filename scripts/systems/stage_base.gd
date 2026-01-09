extends Node3D
class_name StageBase

## Base class for all stages - handles gates, fall detection, checkpoints

@export var stage_number: int = 1
@export var time_limit: float = 60.0

var _player_bike: BikeController
var _stage_active: bool = false
var _hud: RunHUD
var _stage_clear_overlay: StageClearOverlay
var _run_failed_overlay: RunFailedOverlay
var _last_checkpoint_position: Vector3

@onready var start_gate: Area3D = $StartGate
@onready var finish_gate: Area3D = $FinishGate
@onready var fall_plane: Area3D = $FallPlane
@onready var spawn_point: Marker3D = $SpawnPoint

var _checkpoints: Array[Area3D] = []


func _ready() -> void:
	_setup_ui()
	_setup_gates()
	_spawn_player()
	_start_stage()


func _setup_ui() -> void:
	# Instantiate HUD
	var hud_scene: PackedScene = preload("res://scenes/ui/run_hud.tscn")
	_hud = hud_scene.instantiate()
	add_child(_hud)

	# Instantiate stage clear overlay
	var clear_scene: PackedScene = preload("res://scenes/ui/stage_clear_overlay.tscn")
	_stage_clear_overlay = clear_scene.instantiate()
	add_child(_stage_clear_overlay)
	_stage_clear_overlay.continue_pressed.connect(_on_continue_pressed)
	_stage_clear_overlay.cash_out_pressed.connect(_on_cash_out_pressed)

	# Instantiate run failed overlay
	var failed_scene: PackedScene = preload("res://scenes/ui/run_failed_overlay.tscn")
	_run_failed_overlay = failed_scene.instantiate()
	add_child(_run_failed_overlay)
	_run_failed_overlay.returning_to_hub.connect(_on_returning_to_hub)


func _on_continue_pressed() -> void:
	# Advance to next stage
	RunManager.continue_to_next_stage()
	var next_stage_path: String = RunManager.get_stage_scene_path(RunManager.current_stage)
	if next_stage_path != "":
		get_tree().change_scene_to_file(next_stage_path)
	else:
		# No more stages, return to hub
		_return_to_hub()


func _on_cash_out_pressed() -> void:
	_return_to_hub()


func _on_returning_to_hub() -> void:
	_return_to_hub()


func _return_to_hub() -> void:
	get_tree().change_scene_to_file("res://scenes/hub/hub.tscn")


func _setup_gates() -> void:
	if finish_gate:
		finish_gate.body_entered.connect(_on_finish_gate_entered)

	if fall_plane:
		fall_plane.body_entered.connect(_on_fall_plane_entered)


func _spawn_player() -> void:
	var bike_scene: PackedScene = preload("res://scenes/bike/bike.tscn")
	_player_bike = bike_scene.instantiate()
	add_child(_player_bike)

	# Set position after adding to tree
	if spawn_point:
		_player_bike.global_position = spawn_point.global_position
		_last_checkpoint_position = spawn_point.global_position
	else:
		_player_bike.global_position = Vector3(0, 1, 0)
		_last_checkpoint_position = Vector3(0, 1, 0)
	
	# Connect to all checkpoint areas in the scene and store them for debug teleport
	for child in get_children():
		if child.name.begins_with("Checkpoint") and child is Area3D:
			child.body_entered.connect(_on_checkpoint_entered.bind(child))
			_checkpoints.append(child)
	
	# Sort checkpoints by Z position
	_checkpoints.sort_custom(func(a: Area3D, b: Area3D) -> bool: return a.global_position.z < b.global_position.z)


func _start_stage() -> void:
	_stage_active = true
	# Just activate the stage without starting the timer/run system
	RunManager.current_state = RunManager.RunState.IN_RUN
	RunManager.current_stage = stage_number


func _on_finish_gate_entered(body: Node3D) -> void:
	if body == _player_bike and _stage_active:
		_stage_active = false
		RunManager.complete_stage()


func _on_fall_plane_entered(body: Node3D) -> void:
	if body == _player_bike and _stage_active:
		# Respawn at last checkpoint
		_player_bike.reset_position(_last_checkpoint_position)


func _on_checkpoint_entered(body: Node3D, checkpoint: Area3D) -> void:
	if body == _player_bike:
		# Update checkpoint - spawn slightly above the checkpoint
		_last_checkpoint_position = checkpoint.global_position + Vector3(0, 1.5, 0)


func reset_stage() -> void:
	if _player_bike and spawn_point:
		_player_bike.reset_position(spawn_point.global_position)
	_stage_active = true


func _unhandled_key_input(event: InputEvent) -> void:
	# Debug: Press 0-9 to teleport to checkpoints
	if not event.pressed or event.echo:
		return
	
	var key_event: InputEventKey = event as InputEventKey
	if not key_event:
		return
	
	# 0 = spawn point, 1-9 = checkpoints
	if key_event.keycode == KEY_0 or key_event.physical_keycode == KEY_0:
		if spawn_point and _player_bike:
			_teleport_bike(spawn_point.global_position)
			print("Teleported to spawn point")
	
	# Check number keys 1-9
	for i in range(1, 10):
		var key_const: int = KEY_0 + i
		if key_event.keycode == key_const or key_event.physical_keycode == key_const:
			var checkpoint_index: int = i - 1
			if checkpoint_index < _checkpoints.size() and _player_bike:
				var checkpoint_pos: Vector3 = _checkpoints[checkpoint_index].global_position + Vector3(0, 1.5, 0)
				_teleport_bike(checkpoint_pos)
				print("Teleported to checkpoint ", i)
			else:
				print("Checkpoint ", i, " not found (have ", _checkpoints.size(), " checkpoints)")
			break


func _teleport_bike(pos: Vector3) -> void:
	if not _player_bike:
		return
	
	# For RigidBody3D, we need to properly reset physics state
	_player_bike.linear_velocity = Vector3.ZERO
	_player_bike.angular_velocity = Vector3.ZERO
	_player_bike.global_transform = Transform3D(Basis.IDENTITY, pos)
	_last_checkpoint_position = pos
	
	# Also call the bike's reset to clear internal state
	_player_bike.call_deferred("reset_position", pos)
