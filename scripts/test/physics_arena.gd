extends Node3D
class_name PhysicsArena

## Physics Sandbox Arena - flat street environment for testing bike physics

var _player_bike: BikeController

@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	_spawn_player()
	GameManager.start_game()


func _spawn_player() -> void:
	var bike_scene: PackedScene = preload("res://scenes/bike/bike.tscn")
	_player_bike = bike_scene.instantiate()
	add_child(_player_bike)

	if spawn_point:
		_player_bike.global_position = spawn_point.global_position
	else:
		_player_bike.global_position = Vector3(0, 1, 0)


func _input(event: InputEvent) -> void:
	# R to reset position
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if _player_bike and spawn_point:
			_player_bike.reset_position(spawn_point.global_position)

	# ESC to quit
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
