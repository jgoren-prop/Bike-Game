extends Node3D
class_name PhysicsArena

## Physics Sandbox Arena - flat street environment for testing bike physics

var _player_bike: BikeController
var _flip_notification: FlipNotification

@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	_spawn_player()
	_setup_flip_notification()
	GameManager.start_game()


func _spawn_player() -> void:
	var bike_scene: PackedScene = preload("res://scenes/bike/bike.tscn")
	_player_bike = bike_scene.instantiate()
	add_child(_player_bike)

	if spawn_point:
		_player_bike.global_position = spawn_point.global_position
	else:
		_player_bike.global_position = Vector3(0, 1, 0)


func _setup_flip_notification() -> void:
	## Add flip notification UI for trick feedback
	var flip_scene: PackedScene = preload("res://scenes/ui/flip_notification.tscn")
	var canvas := CanvasLayer.new()
	canvas.name = "FlipUI"
	add_child(canvas)
	_flip_notification = flip_scene.instantiate()
	canvas.add_child(_flip_notification)
	
	# Connect to bike's flip signal
	if _player_bike:
		_player_bike.flip_completed.connect(_on_flip_completed)


func _on_flip_completed(flip_type: String, rotation_count: int) -> void:
	if _flip_notification:
		_flip_notification.show_flip(flip_type, rotation_count)


func _input(event: InputEvent) -> void:
	# R to reset position
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if _player_bike and spawn_point:
			_player_bike.reset_position(spawn_point.global_position)

	# ESC to quit
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
