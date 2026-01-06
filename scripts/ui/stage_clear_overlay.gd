extends CanvasLayer
class_name StageClearOverlay

## Overlay shown when a stage is cleared - cash out or continue

@onready var time_label: Label = $Panel/VBoxContainer/TimeLabel
@onready var pot_label: Label = $Panel/VBoxContainer/PotLabel
@onready var next_pot_label: Label = $Panel/VBoxContainer/NextPotLabel
@onready var cash_out_button: Button = $Panel/VBoxContainer/HBoxContainer/CashOutButton
@onready var continue_button: Button = $Panel/VBoxContainer/HBoxContainer/ContinueButton

signal cash_out_pressed
signal continue_pressed


func _ready() -> void:
	cash_out_button.pressed.connect(_on_cash_out_pressed)
	continue_button.pressed.connect(_on_continue_pressed)
	hide()

	RunManager.stage_cleared.connect(_on_stage_cleared)


func _on_stage_cleared(stage_num: int, time_taken: float) -> void:
	_show_overlay(stage_num, time_taken)


func _show_overlay(stage_num: int, time_taken: float) -> void:
	var time_limit: float = RunManager.get_time_limit_for_stage(stage_num)
	time_label.text = "Time: %.2f / %.2f" % [time_taken, time_limit]

	pot_label.text = "Pot: $%d" % Economy.pot

	var next_pot: int = RunManager.get_next_stage_pot()
	if stage_num >= RunManager.MAX_STAGE:
		next_pot_label.text = "Final Stage Complete!"
		continue_button.text = "COLLECT"
	else:
		next_pot_label.text = "Next Stage Pot: $%d" % next_pot
		continue_button.text = "CONTINUE"

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	show()


func _on_cash_out_pressed() -> void:
	hide()
	RunManager.cash_out()
	cash_out_pressed.emit()


func _on_continue_pressed() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	RunManager.continue_to_next_stage()
	continue_pressed.emit()
