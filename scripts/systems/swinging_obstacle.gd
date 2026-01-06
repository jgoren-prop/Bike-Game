extends Node3D
class_name SwingingObstacle

## A pendulum-style swinging obstacle that can knock the player off

@export var swing_angle: float = 60.0  # Degrees
@export var swing_speed: float = 2.0
@export var knockback_force: float = 15.0

var _time: float = 0.0
@onready var _hitbox: Area3D = $Hitbox


func _ready() -> void:
	if _hitbox:
		_hitbox.body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta * swing_speed
	rotation.z = deg_to_rad(sin(_time) * swing_angle)


func _on_body_entered(body: Node3D) -> void:
	if body is BikeController:
		# Apply knockback
		var knockback_dir: Vector3 = (body.global_position - global_position).normalized()
		knockback_dir.y = 0.3
		body.velocity = knockback_dir * knockback_force
