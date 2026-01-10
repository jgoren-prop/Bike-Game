extends Node3D
class_name TestPark

## Test Park - A playground for testing bike movement with various obstacles

var _player_bike: BikeController
var _flip_notification: FlipNotification

@onready var spawn_point: Marker3D = $SpawnPoint


func _ready() -> void:
	_spawn_player()
	_setup_flip_notification()
	GameManager.start_game()


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

	# Number keys 1-4 to teleport to different areas
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_teleport_to("RampArea")
			KEY_2:
				_teleport_to("RailArea")
			KEY_3:
				_teleport_to("HalfPipeArea")
			KEY_4:
				_teleport_to("ObstacleArea")

	# ESC to quit
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()


func _teleport_to(area_name: String) -> void:
	var area_node: Node3D = get_node_or_null(area_name)
	if area_node and _player_bike:
		var spawn: Marker3D = area_node.get_node_or_null("AreaSpawn")
		if spawn:
			_player_bike.reset_position(spawn.global_position)
