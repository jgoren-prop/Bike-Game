extends Node3D
class_name TippingTest

## Test scene for debugging bike tipping behavior on steep slopes.
## Features:
## - Multiple ramps at different angles (30°, 45°, 60°)
## - Spawns bike sideways on selected ramp
## - Key controls to switch between ramps

var _player_bike: BikeController = null
var _current_ramp_index: int = 1  # Start on 45° ramp

@onready var spawn_point_30: Marker3D = $Ramps/Ramp30/SpawnPoint
@onready var spawn_point_45: Marker3D = $Ramps/Ramp45/SpawnPoint
@onready var spawn_point_60: Marker3D = $Ramps/Ramp60/SpawnPoint

var _spawn_points: Array[Marker3D]
var _ramp_angles: Array[int] = [30, 45, 60]


func _ready() -> void:
	_spawn_points = [spawn_point_30, spawn_point_45, spawn_point_60]
	_spawn_bike_at_ramp(_current_ramp_index)
	GameManager.start_game()
	
	# Show instructions
	print("=== TIPPING TEST SCENE ===")
	print("1/2/3 - Switch to 30°/45°/60° ramp")
	print("R - Reset position on current ramp")
	print("F1 - Toggle dev panel")
	print("ESC - Quit")


func _spawn_bike_at_ramp(ramp_index: int) -> void:
	# Remove old bike if exists
	if _player_bike:
		_player_bike.queue_free()
		_player_bike = null
	
	_current_ramp_index = ramp_index
	var spawn: Marker3D = _spawn_points[ramp_index]
	
	# Instantiate fresh bike
	var bike_scene: PackedScene = preload("res://scenes/bike/bike.tscn")
	_player_bike = bike_scene.instantiate()
	add_child(_player_bike)
	
	# Set position and rotation BEFORE first physics frame (like physics_arena does)
	_player_bike.global_position = spawn.global_position + Vector3(0, 0.5, 0)
	_player_bike.global_transform.basis = spawn.global_transform.basis
	
	print("Spawned bike at %d° ramp" % _ramp_angles[ramp_index])


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				_spawn_bike_at_ramp(0)
			KEY_2:
				_spawn_bike_at_ramp(1)
			KEY_3:
				_spawn_bike_at_ramp(2)
			KEY_R:
				_spawn_bike_at_ramp(_current_ramp_index)
			KEY_ESCAPE:
				get_tree().quit()
