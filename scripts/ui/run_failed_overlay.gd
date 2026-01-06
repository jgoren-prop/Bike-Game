extends CanvasLayer
class_name RunFailedOverlay

## Overlay shown when a run fails

@onready var reason_label: Label = $Panel/VBoxContainer/ReasonLabel
@onready var pot_lost_label: Label = $Panel/VBoxContainer/PotLostLabel

var _return_delay: float = 3.0
var _return_timer: float = 0.0
var _is_active: bool = false

signal returning_to_hub


func _ready() -> void:
	hide()
	RunManager.run_failed.connect(_on_run_failed)


func _process(delta: float) -> void:
	if _is_active:
		_return_timer -= delta
		if _return_timer <= 0:
			_is_active = false
			hide()
			returning_to_hub.emit()


func _on_run_failed(reason: String) -> void:
	_show_overlay(reason)


func _show_overlay(reason: String) -> void:
	reason_label.text = reason

	# Show what was lost (pot was already cleared by RunManager)
	pot_lost_label.text = "Pot Lost: $%d" % _get_pot_that_was_lost()

	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_return_timer = _return_delay
	_is_active = true
	show()


func _get_pot_that_was_lost() -> int:
	# Calculate what the pot was based on current stage
	return Economy.calculate_pot_for_stage(RunManager.current_stage)
