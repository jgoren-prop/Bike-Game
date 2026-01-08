extends RigidBody3D
class_name BikeController

## Trials-Style Bike Controller using RigidBody3D
## Real physics-based movement with wheelies, stoppies, and full rotation

# === PHYSICS PARAMETERS ===
# Movement
@export var engine_force: float = 2400.0     # Forward thrust (Newtons)
@export var brake_force: float = 3500.0      # Braking force (snappy stops)
@export var max_speed: float = 18.0          # Speed limiter (m/s)

# Steering
@export var steer_torque: float = 600.0      # Yaw torque for turning
@export var steer_speed_factor: float = 0.4  # Less steering at high speed

# Balance/Lean (Trials-style: W/S = throttle + lean)
@export var lean_torque: float = 150.0       # Pitch torque from input
@export var pitch_stabilization: float = 50.0 # Pitch stability when grounded
@export var roll_stabilization: float = 100.0 # Roll stability (keep upright)

# Lean/Drift Physics
@export var lean_factor: float = 0.15        # How much speed*turn affects lean
@export var lean_response: float = 12.0      # How fast bike reaches target lean (snappy arcade)
@export var max_lean_angle: float = 0.6      # ~35 degrees max lean (radians)
@export var base_grip: float = 1.0           # Tire grip coefficient
@export var rear_grip_bias: float = 0.7      # Rear has less grip (enables drifts)

# Jump
@export var jump_impulse: float = 400.0      # Upward impulse when jumping

# Arcade Feel Parameters
@export var velocity_alignment: float = 6.0   # How fast velocity aligns to facing (lower = more drift)
@export var air_pitch_torque: float = 200.0   # Air flip responsiveness
@export var air_yaw_torque: float = 50.0      # Air spin responsiveness
@export var fov_boost: float = 1.0            # Max FOV increase at top speed
@export var landing_squash_amount: float = 0.1  # Visual squash on landing

# Camera Parameters
@export var base_fov: float = 65.0            # Base field of view
@export var camera_distance: float = 5.5      # Distance behind bike
@export var camera_height: float = 3.0        # Height above bike
@export var camera_angle: float = 16.0        # Pitch angle (degrees) - how much camera looks down

# === INTERNAL STATE ===
var _front_grounded: bool = false
var _rear_grounded: bool = false
var _front_contact_point: Vector3
var _rear_contact_point: Vector3
var _front_normal: Vector3
var _rear_normal: Vector3

var _camera_yaw: float = PI
var _mouse_active: bool = false
var _mouse_cooldown: float = 0.0

# Animation
var _wheel_rotation: float = 0.0
var _steering_angle: float = 0.0
var _visual_lean: float = 0.0  # Visual lean angle for BikeModel
const WHEEL_RADIUS: float = 0.35

# Yaw tracking
var _last_yaw_vel: float = 0.0
var _target_yaw: float = 0.0  # Locked yaw when not steering
var _yaw_locked: bool = false

# Landing impact feel
var _was_airborne: bool = false
var _landing_squash: float = 0.0


# Node references
@onready var _bike_model: Node3D = $BikeModel
@onready var _front_assembly: Node3D = $BikeModel/FrontAssembly
@onready var _front_wheel: Node3D = $BikeModel/FrontAssembly/FrontWheel
@onready var _rear_wheel: Node3D = $BikeModel/RearWheel
@onready var _pedal_arm_left: MeshInstance3D = $BikeModel/PedalArmLeft
@onready var _pedal_arm_right: MeshInstance3D = $BikeModel/PedalArmRight
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _front_wheel_ray: RayCast3D = $FrontWheelRay
@onready var _rear_wheel_ray: RayCast3D = $RearWheelRay

signal speed_changed(speed: float)


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Make camera independent of bike rotation (won't flip when bike flips)
	_camera_pivot.top_level = true
	_camera_pivot.global_position = global_position + Vector3(0, 1, 0)
	_camera_pivot.rotation.y = _camera_yaw


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
	_camera_pivot.rotation.y = _camera_yaw
	_mouse_active = true
	_mouse_cooldown = 0.3


func _physics_process(delta: float) -> void:
	_check_ground()

	var throttle: float = Input.get_axis("brake", "accelerate")
	var steer: float = Input.get_axis("steer_right", "steer_left")

	# Get bike's forward direction (local +Z in world space, since front wheel is at +Z)
	var forward: Vector3 = global_transform.basis.z
	var right: Vector3 = global_transform.basis.x

	# === DRIVE FORCE ===
	# Apply at rear wheel contact point for natural weight transfer
	if throttle > 0:
		# Punchy acceleration - strong at low speed, tapering at high
		var current_speed: float = linear_velocity.length()
		var speed_ratio: float = clamp(current_speed / max_speed, 0.0, 1.0)
		var accel_curve: float = 1.0 - (speed_ratio * speed_ratio * 0.6)  # Quadratic falloff
		var force_vec: Vector3 = forward * throttle * engine_force * accel_curve
		if _rear_grounded:
			# Apply force at wheel contact - creates natural wheelie torque!
			var force_pos: Vector3 = _rear_contact_point - global_position
			apply_force(force_vec, force_pos)
		else:
			# In air or no ground contact - apply central force
			apply_central_force(force_vec * 0.5)

	# === BRAKE / REVERSE ===
	if throttle < 0:
		var dominated_forward: float = linear_velocity.dot(forward)
		if dominated_forward > 1.0:
			# Moving forward - apply brakes
			var brake_dir: Vector3 = -linear_velocity.normalized()
			if _front_grounded:
				var force_pos: Vector3 = _front_contact_point - global_position
				apply_force(brake_dir * abs(throttle) * brake_force * 0.7, force_pos)
			if _rear_grounded:
				var force_pos: Vector3 = _rear_contact_point - global_position
				apply_force(brake_dir * abs(throttle) * brake_force * 0.3, force_pos)
		else:
			# Stopped or moving backward - apply reverse force
			var reverse_force: Vector3 = -forward * abs(throttle) * engine_force * 0.5
			if _rear_grounded:
				var force_pos: Vector3 = _rear_contact_point - global_position
				apply_force(reverse_force, force_pos)
			else:
				apply_central_force(reverse_force * 0.3)

	# === STEERING & LEAN ===
	var is_grounded: bool = _front_grounded or _rear_grounded

	if is_grounded:
		# Ground steering - power scales with camera angle for drift control
		var steer_torque_applied: Vector3 = Vector3.ZERO
		if linear_velocity.length() > 0.5:
			# Reduce steering at high speed
			var high_speed_factor: float = 1.0 - (linear_velocity.length() / max_speed) * steer_speed_factor
			high_speed_factor = clamp(high_speed_factor, 0.4, 1.0)
			# Also reduce steering at low speed (ramps up from 0 to 1 between 0-8 m/s)
			var low_speed_factor: float = clamp(linear_velocity.length() / 8.0, 0.1, 1.0)
			var speed_factor: float = high_speed_factor * low_speed_factor
			var throttle_boost: float = 1.0 + abs(throttle) * 0.5

			# Camera angle boost - how much camera is offset from bike facing
			var camera_offset: float = _camera_yaw - global_rotation.y
			# Normalize to [-PI, PI]
			while camera_offset > PI:
				camera_offset -= TAU
			while camera_offset < -PI:
				camera_offset += TAU

			# Boost turn power when steering toward where camera is looking
			# camera_offset > 0 = looking left, steer > 0 = steering left
			# Camera boost only kicks in at higher speeds (need momentum to drift)
			var look_alignment: float = camera_offset * steer  # Positive when aligned
			var camera_boost: float = 1.0 + clamp(look_alignment, 0.0, 0.5) * low_speed_factor  # Up to 1.5x boost

			steer_torque_applied = Vector3.UP * steer * steer_torque * speed_factor * throttle_boost * camera_boost
			apply_torque(steer_torque_applied)

		# Ground lean control (Trials-style: W/S = lean)
		# Use horizontal right vector to prevent yaw influence
		var horizontal_right: Vector3 = Vector3(right.x, 0, right.z).normalized()
		var lean_torque_applied: Vector3 = horizontal_right * throttle * lean_torque
		apply_torque(lean_torque_applied)

		# === VELOCITY ALIGNMENT (instant drift recovery) ===
		# Rotate velocity toward facing direction - key arcade technique
		var vel_2d := Vector2(linear_velocity.x, linear_velocity.z)
		var facing_2d := Vector2(forward.x, forward.z).normalized()
		if vel_2d.length() > 2.0:
			var vel_normalized := vel_2d.normalized()
			var aligned_vel := vel_normalized.lerp(facing_2d, velocity_alignment * delta)
			aligned_vel = aligned_vel.normalized() * vel_2d.length()
			linear_velocity.x = aligned_vel.x
			linear_velocity.z = aligned_vel.y

		# Track yaw while actively steering
		if abs(steer) > 0.1:
			_last_yaw_vel = angular_velocity.y
			_yaw_locked = false  # Unlock while steering
		elif not _yaw_locked:
			# Just stopped steering - lock the current yaw
			_target_yaw = global_rotation.y
			_yaw_locked = true
	else:
		# === AIR CONTROL ===
		# Air pitch for flips (W/S) - very responsive
		apply_torque(right * throttle * air_pitch_torque)

		# Air yaw (A/D) - responsive spin
		apply_torque(Vector3.UP * steer * air_yaw_torque)
		# Note: removed 0.98 damping - angular_damp handles it now

	# === YAW HANDLING (END OF FRAME) ===
	var speed: float = linear_velocity.length()

	if is_grounded and abs(steer) < 0.1 and _yaw_locked:
		# Not steering - actively hold the locked yaw
		var yaw_error: float = _target_yaw - global_rotation.y
		# Wrap angle difference to [-PI, PI]
		while yaw_error > PI:
			yaw_error -= TAU
		while yaw_error < -PI:
			yaw_error += TAU

		# Directly correct yaw rotation
		var current_rot: Vector3 = global_rotation
		current_rot.y = _target_yaw
		global_rotation = current_rot

		# Zero yaw angular velocity
		angular_velocity.y = 0.0

	# Calculate visual lean for BikeModel (separate from physics)
	var target_visual_lean: float = 0.0
	if is_grounded and speed > 1.0:
		# Drift lean - lean OPPOSITE to slip angle (counter-steer visual)
		# This looks like the rider is leaning their body to counter the drift
		var vel_horizontal: Vector3 = Vector3(linear_velocity.x, 0, linear_velocity.z)
		if vel_horizontal.length() > 2.0:
			var slip_angle: float = forward.signed_angle_to(vel_horizontal.normalized(), Vector3.UP)
			# Counter-lean: positive multiplier = lean opposite to drift direction
			target_visual_lean = slip_angle * 1.5
			target_visual_lean = clamp(target_visual_lean, -max_lean_angle, max_lean_angle)

		# Add steering lean on top (lean into the turn when steering)
		var steer_lean: float = -steer * 0.4
		target_visual_lean += steer_lean
		target_visual_lean = clamp(target_visual_lean, -max_lean_angle, max_lean_angle)

	# Snap to target lean - arcade style (instant recovery, quick lean-in)
	var lean_speed: float = 0.95 if abs(target_visual_lean) < abs(_visual_lean) else 0.85
	_visual_lean = lerp(_visual_lean, target_visual_lean, lean_speed)

	# Gentle pitch stabilization when grounded (helps balance)
	if is_grounded and abs(throttle) < 0.1:
		var current_pitch: float = global_rotation.x
		apply_torque(right * -current_pitch * pitch_stabilization)

	# === PHYSICS BODY ROLL LOCK (NEVER TIP) ===
	# The physics body stays upright - visual lean is handled by BikeModel
	# Absolute roll lock when grounded - impossible to tip over
	if is_grounded:
		# Zero out roll rotation directly - instant lock
		var current_rot: Vector3 = global_rotation
		current_rot.z = 0.0
		global_rotation = current_rot

		# Kill all roll angular velocity immediately
		var horizontal_forward: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
		var roll_ang_vel: float = angular_velocity.dot(horizontal_forward)
		angular_velocity -= horizontal_forward * roll_ang_vel
	elif speed < 5.0:
		# Even when not fully grounded, prevent roll at low speeds
		var current_rot: Vector3 = global_rotation
		current_rot.z = lerp(current_rot.z, 0.0, 0.8)
		global_rotation = current_rot

	# === SPEED LIMITER ===
	if linear_velocity.length() > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

	# === JUMP ===
	if Input.is_action_just_pressed("jump") and is_grounded:
		apply_central_impulse(Vector3.UP * jump_impulse)

	# === LANDING IMPACT FEEL ===
	if is_grounded and _was_airborne:
		# Just landed - trigger squash!
		_landing_squash = landing_squash_amount
	_was_airborne = not is_grounded

	# Recover from squash quickly
	_landing_squash = lerp(_landing_squash, 0.0, 10.0 * delta)

	# === CAMERA ===
	_update_camera(delta)

	# === ANIMATION ===
	_animate_bike(delta)

	# Emit speed
	speed_changed.emit(get_current_speed())


func _check_ground() -> void:
	# Front wheel
	_front_grounded = _front_wheel_ray.is_colliding()
	if _front_grounded:
		_front_contact_point = _front_wheel_ray.get_collision_point()
		_front_normal = _front_wheel_ray.get_collision_normal()

	# Rear wheel
	_rear_grounded = _rear_wheel_ray.is_colliding()
	if _rear_grounded:
		_rear_contact_point = _rear_wheel_ray.get_collision_point()
		_rear_normal = _rear_wheel_ray.get_collision_normal()


func _update_camera(delta: float) -> void:
	# Update mouse cooldown
	if _mouse_cooldown > 0:
		_mouse_cooldown -= delta
		if _mouse_cooldown <= 0:
			_mouse_active = false

	var speed: float = linear_velocity.length()
	var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)

	# === DYNAMIC FOV (speed sensation) ===
	var target_fov: float = base_fov + (speed_ratio * speed_ratio * fov_boost)
	_camera.fov = lerp(_camera.fov, target_fov, 5.0 * delta)

	# === CAMERA POSITION ===
	var height_reduction: float = 0.8  # Drop up to 0.8 units at max speed
	var target_height: float = camera_height - (speed_ratio * height_reduction)

	# Smoothly follow bike position (camera is top_level so we do this manually)
	var target_pos: Vector3 = global_position + Vector3(0, 1, 0)
	_camera_pivot.global_position = _camera_pivot.global_position.lerp(target_pos, 10.0 * delta)

	# Adjust camera local position for height and distance
	_camera.position.y = lerp(_camera.position.y, target_height, 3.0 * delta)
	_camera.position.z = lerp(_camera.position.z, -camera_distance, 3.0 * delta)

	# Adjust camera angle (pitch) - negate so positive = look down
	var target_angle: float = deg_to_rad(-camera_angle)
	_camera.rotation.x = lerp(_camera.rotation.x, target_angle, 3.0 * delta)

	if not _mouse_active:
		# Get horizontal direction - prefer velocity when moving, else bike forward
		var horizontal_dir: Vector3
		var horiz_vel: Vector3 = Vector3(linear_velocity.x, 0, linear_velocity.z)

		if horiz_vel.length() > 2.0:
			# Moving - follow velocity direction (stable during flips)
			horizontal_dir = horiz_vel.normalized()
		else:
			# Slow/stopped - use bike's forward projected to horizontal
			var fwd: Vector3 = global_transform.basis.z
			horizontal_dir = Vector3(fwd.x, 0, fwd.z)
			if horizontal_dir.length() > 0.1:
				horizontal_dir = horizontal_dir.normalized()
			else:
				horizontal_dir = Vector3.FORWARD

		var target_yaw: float = atan2(horizontal_dir.x, horizontal_dir.z)
		_camera_yaw = lerp_angle(_camera_yaw, target_yaw, 6.0 * delta)

	# Always keep camera upright (only rotate on Y axis)
	_camera_pivot.rotation = Vector3(0, _camera_yaw, 0)


func _animate_bike(delta: float) -> void:
	if not _bike_model:
		return

	# Apply visual lean to bike model (physics body stays upright)
	_bike_model.rotation.z = _visual_lean

	# Apply landing squash effect (compress Y, expand X/Z)
	_bike_model.scale.y = 1.0 - _landing_squash
	_bike_model.scale.x = 1.0 + _landing_squash * 0.5
	_bike_model.scale.z = 1.0 + _landing_squash * 0.5

	var speed: float = linear_velocity.length()

	# Wheel rotation based on speed
	var wheel_circumference: float = 2.0 * PI * WHEEL_RADIUS
	var rotations_per_second: float = speed / wheel_circumference

	# Check if moving forward or backward relative to bike facing
	var forward: Vector3 = global_transform.basis.z
	var velocity_dot: float = linear_velocity.dot(forward)
	if velocity_dot < 0:
		rotations_per_second = -rotations_per_second

	_wheel_rotation += rotations_per_second * 2.0 * PI * delta

	if _front_wheel:
		_front_wheel.rotation.x = _wheel_rotation
	if _rear_wheel:
		_rear_wheel.rotation.x = _wheel_rotation

	# Handlebar steering visual
	var steer_input: float = Input.get_axis("steer_right", "steer_left")
	var target_steer: float = steer_input * 0.5
	_steering_angle = lerp(_steering_angle, target_steer, 10.0 * delta)
	if _front_assembly:
		_front_assembly.rotation.y = _steering_angle

	# Pedal animation when accelerating
	if Input.is_action_pressed("accelerate") and (_front_grounded or _rear_grounded):
		var pedal_speed: float = 8.0
		if _pedal_arm_left:
			_pedal_arm_left.rotation.y = sin(Time.get_ticks_msec() * 0.01 * pedal_speed) * 0.5
		if _pedal_arm_right:
			_pedal_arm_right.rotation.y = sin(Time.get_ticks_msec() * 0.01 * pedal_speed + PI) * 0.5


# === PUBLIC API ===

func get_current_speed() -> float:
	return linear_velocity.length()


func get_horizontal_speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()


func is_grounded() -> bool:
	return _front_grounded or _rear_grounded


func is_front_grounded() -> bool:
	return _front_grounded


func is_rear_grounded() -> bool:
	return _rear_grounded


func reset_position(pos: Vector3) -> void:
	global_position = pos
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_wheel_rotation = 0.0
	_steering_angle = 0.0
	_visual_lean = 0.0
	_landing_squash = 0.0
	_was_airborne = false
	if _bike_model:
		_bike_model.rotation.z = 0.0
		_bike_model.scale = Vector3.ONE
