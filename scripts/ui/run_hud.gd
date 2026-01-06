extends CanvasLayer
class_name RunHUD

## HUD displayed during runs - shows time, stage, pot

@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var stage_label: Label = $MarginContainer/VBoxContainer/StageLabel
@onready var pot_label: Label = $MarginContainer/VBoxContainer/PotLabel

var _warning_threshold: float = 10.0


func _ready() -> void:
	RunManager.time_updated.connect(_on_time_updated)
	RunManager.stage_started.connect(_on_stage_started)
	Economy.pot_changed.connect(_on_pot_changed)

	_update_stage_display(RunManager.current_stage)
	_update_pot_display(Economy.pot)


func _on_time_updated(time_remaining: float) -> void:
	var minutes: int = int(time_remaining) / 60
	var seconds: int = int(time_remaining) % 60
	var milliseconds: int = int((time_remaining - int(time_remaining)) * 100)

	time_label.text = "TIME: %d:%02d.%02d" % [minutes, seconds, milliseconds]

	# Warning color when low on time
	if time_remaining <= _warning_threshold:
		time_label.modulate = Color.RED
	else:
		time_label.modulate = Color.WHITE


func _on_stage_started(stage_num: int) -> void:
	_update_stage_display(stage_num)
	time_label.modulate = Color.WHITE


func _update_stage_display(stage_num: int) -> void:
	stage_label.text = "STAGE %d" % stage_num


func _on_pot_changed(new_pot: int) -> void:
	_update_pot_display(new_pot)


func _update_pot_display(pot: int) -> void:
	pot_label.text = "POT: $%d" % pot
