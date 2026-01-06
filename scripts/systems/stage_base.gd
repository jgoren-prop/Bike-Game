extends Node3D
class_name StageBase

## Base class for all stages - handles gates, fall detection, timing

@export var stage_number: int = 1
@export var time_limit: float = 60.0

var _player_bike: BikeController
var _stage_active: bool = false
var _hud: RunHUD
var _stage_clear_overlay: StageClearOverlay
var _run_failed_overlay: RunFailedOverlay

@onready var start_gate: Area3D = $StartGate
@onready var finish_gate: Area3D = $FinishGate
@onready var fall_plane: Area3D = $FallPlane
@onready var spawn_point: Marker3D = $SpawnPoint


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
	else:
		_player_bike.global_position = Vector3(0, 1, 0)


func _start_stage() -> void:
	_stage_active = true
	# Only start a new run if we're not already in one
	# (continue_to_next_stage already handles timer for subsequent stages)
	if RunManager.current_state == RunManager.RunState.IDLE:
		RunManager.start_run()


func _on_finish_gate_entered(body: Node3D) -> void:
	if body == _player_bike and _stage_active:
		_stage_active = false
		RunManager.complete_stage()


func _on_fall_plane_entered(body: Node3D) -> void:
	if body == _player_bike and _stage_active:
		_stage_active = false
		RunManager.fail_run("Fell off the course")


func reset_stage() -> void:
	if _player_bike and spawn_point:
		_player_bike.reset_position(spawn_point.global_position)
	_stage_active = true
