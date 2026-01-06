extends Node3D
class_name Hub

## Hub scene - player starts runs from here

@onready var start_gate: Area3D = $StartGate
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var wallet_label: Label = $HubUI/MarginContainer/VBoxContainer/WalletLabel
@onready var best_stage_label: Label = $HubUI/MarginContainer/VBoxContainer/BestStageLabel

var _player_bike: BikeController
var _best_stage: int = 0


func _ready() -> void:
	_spawn_player()
	_setup_gate()
	_update_ui()

	# Connect to economy changes
	Economy.wallet_changed.connect(_on_wallet_changed)


func _spawn_player() -> void:
	var bike_scene: PackedScene = preload("res://scenes/bike/bike.tscn")
	_player_bike = bike_scene.instantiate()
	add_child(_player_bike)

	if spawn_point:
		_player_bike.global_position = spawn_point.global_position


func _setup_gate() -> void:
	if start_gate:
		start_gate.body_entered.connect(_on_start_gate_entered)


func _on_start_gate_entered(body: Node3D) -> void:
	if body == _player_bike:
		_start_run()


func _start_run() -> void:
	# Change to stage 1
	get_tree().change_scene_to_file("res://scenes/stages/test_stage.tscn")


func _update_ui() -> void:
	if wallet_label:
		wallet_label.text = "WALLET: $%d" % Economy.wallet
	if best_stage_label:
		best_stage_label.text = "BEST: Stage %d" % _best_stage


func _on_wallet_changed(_new_amount: int) -> void:
	_update_ui()


func set_best_stage(stage: int) -> void:
	if stage > _best_stage:
		_best_stage = stage
		_update_ui()
