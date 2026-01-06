extends StaticBody3D
class_name FallingPlatform

## Platform that shakes and falls after player touches it

@export var shake_time: float = 0.8
@export var fall_speed: float = 15.0
@export var respawn_time: float = 3.0

var _triggered: bool = false
var _falling: bool = false
var _start_position: Vector3
var _shake_timer: float = 0.0

@onready var _mesh: MeshInstance3D = $Mesh
@onready var _collision: CollisionShape3D = $Collision
@onready var _trigger: Area3D = $Trigger


func _ready() -> void:
	_start_position = global_position
	if _trigger:
		_trigger.body_entered.connect(_on_trigger_entered)


func _process(delta: float) -> void:
	if _triggered and not _falling:
		_shake_timer += delta
		# Shake effect
		_mesh.position.x = sin(_shake_timer * 50) * 0.05
		_mesh.position.z = cos(_shake_timer * 40) * 0.05

		if _shake_timer >= shake_time:
			_start_falling()

	if _falling:
		global_position.y -= fall_speed * delta
		if global_position.y < -50:
			_respawn()


func _on_trigger_entered(body: Node3D) -> void:
	if body is BikeController and not _triggered:
		_triggered = true
		_shake_timer = 0.0


func _start_falling() -> void:
	_falling = true
	_collision.disabled = true


func _respawn() -> void:
	await get_tree().create_timer(respawn_time).timeout
	global_position = _start_position
	_mesh.position = Vector3.ZERO
	_collision.disabled = false
	_triggered = false
	_falling = false
