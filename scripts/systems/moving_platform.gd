extends AnimatableBody3D
class_name MovingPlatform

## A platform that moves between two points

@export var move_distance: Vector3 = Vector3(10, 0, 0)
@export var move_duration: float = 3.0
@export var pause_duration: float = 0.5

var _start_position: Vector3
var _end_position: Vector3
var _tween: Tween


func _ready() -> void:
	_start_position = global_position
	_end_position = _start_position + move_distance
	_start_movement()


func _start_movement() -> void:
	_tween = create_tween()
	_tween.set_loops()
	_tween.tween_property(self, "global_position", _end_position, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(pause_duration)
	_tween.tween_property(self, "global_position", _start_position, move_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(pause_duration)
