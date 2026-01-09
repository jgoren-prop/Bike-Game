extends CanvasLayer
class_name RunHUD

## HUD displayed during runs - shows time, stage, pot

@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var stage_label: Label = $MarginContainer/VBoxContainer/StageLabel
@onready var pot_label: Label = $MarginContainer/VBoxContainer/PotLabel



func _ready() -> void:
	RunManager.stage_started.connect(_on_stage_started)
	Economy.pot_changed.connect(_on_pot_changed)

	_update_stage_display(RunManager.current_stage)
	_update_pot_display(Economy.pot)
	
	# Hide timer - no time limit
	if time_label:
		time_label.visible = false


func _on_stage_started(stage_num: int) -> void:
	_update_stage_display(stage_num)


func _update_stage_display(stage_num: int) -> void:
	stage_label.text = "STAGE %d" % stage_num


func _on_pot_changed(new_pot: int) -> void:
	_update_pot_display(new_pot)


func _update_pot_display(pot: int) -> void:
	pot_label.text = "POT: $%d" % pot
