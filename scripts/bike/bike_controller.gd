extends CharacterBody3D
class_name BikeController

## Main bike controller - handles movement, steering, jumping, and physics

# Movement tuning (scaled by stats)
const BASE_MAX_SPEED: float = 20.0
const BASE_ACCELERATION: float = 15.0
const BASE_BRAKE_FORCE: float = 25.0
const BASE_TURN_SPEED: float = 3.0
const BASE_JUMP_FORCE: float = 8.0
const GRAVITY: float = 30.0
const FRICTION: float = 8.0
const AIR_FRICTION: float = 0.5
const STEERING_RETURN_SPEED: float = 5.0  # How fast bike aligns to camera when not steering

# Current stats (set from BikeData)
var max_speed: float = 20.0
var acceleration_force: float = 15.0
var handling_multiplier: float = 1.0
var stability_multiplier: float = 1.0
var jump_efficiency: float = 1.0

# State
var _current_speed: float = 0.0
var _is_grounded: bool = false
var _forward_direction: Vector3 = Vector3(0, 0, 1)  # Start facing +Z (toward goals)
var _camera_yaw: float = PI  # 180 degrees - facing +Z

# Node references
@onready var _mesh: MeshInstance3D = $MeshInstance3D
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _ground_ray: RayCast3D = $GroundRay

signal landed
signal fell_off


func _ready() -> void:
	_load_stats_from_bike_data()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Set initial camera rotation to match forward direction
	_camera_pivot.rotation.y = _camera_yaw
	if _mesh:
		_mesh.rotation.y = atan2(-_forward_direction.x, -_forward_direction.z)


func _load_stats_from_bike_data() -> void:
	var stats: Dictionary = BikeData.get_effective_stats()

	# Scale base values by stat (stats are 1-10, so divide by 6 for baseline)
	var stat_scale: float = 1.0 / 6.0

	max_speed = BASE_MAX_SPEED * stats["top_speed"] * stat_scale
	acceleration_force = BASE_ACCELERATION * stats["acceleration"] * stat_scale
	handling_multiplier = stats["handling"] * stat_scale
	stability_multiplier = stats["stability"] * stat_scale
	jump_efficiency = stats["jump_efficiency"] * stat_scale


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_handle_mouse_look(event)

	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _handle_mouse_look(event: InputEventMouseMotion) -> void:
	var sensitivity: float = 0.002
	_camera_yaw -= event.relative.x * sensitivity

	# Update forward direction based on camera yaw (negative Z is forward in Godot)
	_forward_direction = Vector3(-sin(_camera_yaw), 0, -cos(_camera_yaw)).normalized()

	# Rotate camera pivot
	_camera_pivot.rotation.y = _camera_yaw


func _physics_process(delta: float) -> void:
	var was_grounded: bool = _is_grounded
	_check_grounded()

	# Emit landed signal when touching ground after being airborne
	if _is_grounded and not was_grounded:
		landed.emit()

	_handle_input(delta)
	_apply_gravity(delta)
	_apply_friction(delta)
	_move_bike(delta)

	move_and_slide()


func _check_grounded() -> void:
	_is_grounded = _ground_ray.is_colliding()


func _handle_input(delta: float) -> void:
	# Acceleration (W)
	if Input.is_action_pressed("accelerate"):
		_current_speed += acceleration_force * delta
		_current_speed = min(_current_speed, max_speed)

	# Braking (S)
	if Input.is_action_pressed("brake"):
		_current_speed -= BASE_BRAKE_FORCE * delta
		_current_speed = max(_current_speed, 0.0)

	# Jumping (Space) - only when grounded
	if Input.is_action_just_pressed("jump") and _is_grounded:
		var jump_power: float = BASE_JUMP_FORCE * jump_efficiency
		velocity.y = jump_power

	# Steering (A/D) - only when moving
	if _current_speed > 0.1:
		var turn_input: float = Input.get_axis("steer_right", "steer_left")

		if abs(turn_input) > 0.1:
			# Active steering - rotate around Y axis
			var turn_amount: float = turn_input * BASE_TURN_SPEED * handling_multiplier * delta
			_forward_direction = _forward_direction.rotated(Vector3.UP, turn_amount)
		else:
			# No steering input - lerp back to camera direction
			var camera_forward: Vector3 = Vector3(-sin(_camera_yaw), 0, -cos(_camera_yaw)).normalized()
			_forward_direction = _forward_direction.lerp(camera_forward, STEERING_RETURN_SPEED * delta)

	# Visually rotate the mesh to match movement direction
	if _mesh and _current_speed > 0.1:
		var target_angle: float = atan2(-_forward_direction.x, -_forward_direction.z)
		_mesh.rotation.y = target_angle


func _apply_gravity(delta: float) -> void:
	if not _is_grounded:
		velocity.y -= GRAVITY * delta


func _apply_friction(delta: float) -> void:
	if _is_grounded:
		if not Input.is_action_pressed("accelerate") and not Input.is_action_pressed("brake"):
			_current_speed -= FRICTION * delta
			_current_speed = max(_current_speed, 0.0)
	else:
		# Less friction in air
		_current_speed -= AIR_FRICTION * delta
		_current_speed = max(_current_speed, 0.0)


func _move_bike(delta: float) -> void:
	# Calculate horizontal velocity based on forward direction and speed
	var horizontal_velocity: Vector3 = _forward_direction * _current_speed

	# Apply velocity
	velocity.x = horizontal_velocity.x
	velocity.z = horizontal_velocity.z


func get_current_speed() -> float:
	return _current_speed


func get_speed_percentage() -> float:
	if max_speed <= 0:
		return 0.0
	return _current_speed / max_speed


func reset_position(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	_current_speed = 0.0
