extends Node3D
class_name ClimbBase

## Base controller for the rage game climb world
## Handles spawning, respawning, and UI

var _player_bike: BikeController
var _hud: CanvasLayer
var _is_active: bool = false

@onready var spawn_point: Marker3D = $SpawnPoint
@onready var ground_plane: StaticBody3D = $GroundPlane


func _ready() -> void:
	_setup_ui()
	_spawn_player()
	_start_climb()


func _setup_ui() -> void:
	var hud_scene: PackedScene = preload("res://scenes/ui/climb_hud.tscn")
	_hud = hud_scene.instantiate()
	add_child(_hud)


func _spawn_player() -> void:
	var bike_scene: PackedScene = preload("res://scenes/bike/bike.tscn")
	_player_bike = bike_scene.instantiate()
	add_child(_player_bike)

	if spawn_point:
		_player_bike.global_position = spawn_point.global_position
	else:
		_player_bike.global_position = Vector3(0, 1, 0)

	# Connect crash signal for respawn
	_player_bike.crashed.connect(_on_player_crashed)


func _start_climb() -> void:
	_is_active = true
	ClimbManager.start_climbing()
	GameManager.start_game()


func _on_player_crashed(reason: String) -> void:
	# In rage game, crashes lead to tumbling, not instant respawn
	# The bike handles tumble->recovery automatically
	# We just track it for stats
	pass


func respawn_at_bottom() -> void:
	if _player_bike and spawn_point:
		_player_bike.reset_position(spawn_point.global_position)


func _input(event: InputEvent) -> void:
	# R to manually reset (for testing)
	if event.is_action_pressed("ui_text_clear"):  # Uses existing R key if mapped
		respawn_at_bottom()

	# ESC to return to menu
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			_return_to_menu()


func _return_to_menu() -> void:
	ClimbManager.return_to_menu()
	SaveManager.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
