extends AnimatableBody3D
class_name PusherBlock

## A block that pushes out quickly then retracts slowly

@export var push_distance: Vector3 = Vector3(8, 0, 0)
@export var push_duration: float = 0.3
@export var retract_duration: float = 1.5
@export var wait_time: float = 2.0

var _start_position: Vector3
var _end_position: Vector3


func _ready() -> void:
	_start_position = global_position
	_end_position = _start_position + push_distance
	_start_cycle()


func _start_cycle() -> void:
	var tween: Tween = create_tween()
	tween.set_loops()
	tween.tween_interval(wait_time)
	tween.tween_property(self, "global_position", _end_position, push_duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.2)
	tween.tween_property(self, "global_position", _start_position, retract_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
