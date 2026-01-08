extends Control
class_name MainMenu

## Simple main menu for rage game

@onready var best_height_label: Label = $VBoxContainer/StatsContainer/BestHeightLabel
@onready var attempts_label: Label = $VBoxContainer/StatsContainer/AttemptsLabel
@onready var play_time_label: Label = $VBoxContainer/StatsContainer/PlayTimeLabel
@onready var climb_button: Button = $VBoxContainer/ClimbButton


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_update_stats()
	climb_button.pressed.connect(_on_climb_pressed)


func _update_stats() -> void:
	var stats: Dictionary = SaveManager.get_stats_display()

	if best_height_label:
		best_height_label.text = "Best Height: %.1fm" % stats["best_height"]
	if attempts_label:
		attempts_label.text = "Total Attempts: %d" % stats["total_attempts"]
	if play_time_label:
		var total_seconds: int = int(stats["total_play_time"])
		var hours: int = total_seconds / 3600
		var minutes: int = (total_seconds % 3600) / 60
		var seconds: int = total_seconds % 60
		play_time_label.text = "Play Time: %02d:%02d:%02d" % [hours, minutes, seconds]


func _on_climb_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/tower/climb_world.tscn")
