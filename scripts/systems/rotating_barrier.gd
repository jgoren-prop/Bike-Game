extends Node3D
class_name RotatingBarrier

## A spinning barrier that can knock players off

@export var rotation_speed: float = 2.0
@export var knockback_force: float = 20.0

@onready var _hitbox: Area3D = $Hitbox


func _ready() -> void:
	if _hitbox:
		_hitbox.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	rotate_y(rotation_speed * delta)


func _on_body_entered(body: Node3D) -> void:
	if body is BikeController:
		var knockback_dir: Vector3 = (body.global_position - global_position).normalized()
		knockback_dir.y = 0.5
		body.linear_velocity = knockback_dir * knockback_force
