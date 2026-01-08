extends RigidBody3D
class_name BikeController

## Trials-Style Bike Controller using RigidBody3D
## Real physics-based movement with wheelies, stoppies, and full rotation

# === PHYSICS PARAMETERS ===
# Movement
@export var engine_force: float = 1300.0     # Forward thrust (Newtons)
@export var brake_force: float = 1000.0      # Braking force (snappy stops)
@export var max_speed: float = 16.0          # Speed limiter (m/s)

# Steering
@export var steer_torque: float = 250.0      # Yaw torque for turning
@export var steer_speed_factor: float = 0.4  # Less steering at high speed

# Balance/Lean (W = throttle + tilt forward, S = brake/tilt back)
@export var lean_torque: float = 200.0       # Pitch torque from input
@export var pitch_stabilization: float = 120.0 # Pitch stability when grounded

# Arcade Handling (direct control when not drifting)
@export var velocity_alignment: float = 0.95  # How much velocity snaps to forward (0-1)
@export var drift_grip: float = 3.0          # Grip during drift (higher = tighter turns)
@export var drift_kickout: float = 0.0       # Lateral impulse when starting drift
@export var drift_steer_boost: float = 1.3   # Steering multiplier during drift
@export var max_lean_angle: float = 0.6      # ~35 degrees max lean (radians)

# Jump
@export var jump_impulse: float = 300.0      # Upward impulse when jumping

# Arcade Feel Parameters
@export var air_pitch_torque: float = 350.0   # Air flip responsiveness
@export var air_yaw_torque: float = 180.0      # Air spin responsiveness
@export var fov_boost: float = 1.0            # Max FOV increase at top speed
@export var landing_squash_amount: float = 0.1  # Visual squash on landing
@export var disable_visual_effects: bool = false  # Debug: disable visual lean/squash

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

var _camera_yaw: float = 0.0
var _mouse_control_strength: float = 0.0  # 1.0 = full mouse control, 0.0 = full auto-follow
var _mouse_hold_timer: float = 0.0  # Delay before auto-follow starts returning
var _was_drifting: bool = false  # Track drift state for kickout
var _drift_camera_delay: float = 0.0  # Slow camera during drift entry

# Animation
var _wheel_rotation: float = 0.0
var _steering_angle: float = 0.0
var _visual_lean: float = 0.0  # Visual lean angle (front/frame)
var _rear_lean: float = 0.0    # Rear follows front with delay
const WHEEL_RADIUS: float = 0.35


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
	_mouse_control_strength = 1.0  # Full mouse control when moving mouse
	_mouse_hold_timer = 0.5  # Hold for 500ms before auto-follow starts returning


func _physics_process(delta: float) -> void:
	_check_ground()

	var throttle: float = 1.0 if Input.is_action_pressed("accelerate") else 0.0
	var tilt: float = Input.get_axis("brake", "accelerate")  # W = throttle + tilt, S = brake + tilt back
	var steer: float = Input.get_axis("steer_right", "steer_left")
	var drifting: bool = Input.is_physical_key_pressed(KEY_SHIFT)  # Shift = drift mode

	# Get bike's forward direction (local +Z in world space, since front wheel is at +Z)
	var forward: Vector3 = global_transform.basis.z
	var right: Vector3 = global_transform.basis.x

	# Calculate slope steepness (0 = flat, 1 = vertical wall)
	var slope_factor: float = 0.0
	if _rear_grounded:
		slope_factor = 1.0 - _rear_normal.y
	elif _front_grounded:
		slope_factor = 1.0 - _front_normal.y

	# === DRIVE FORCE ===
	# Apply at rear wheel contact point - only works when rear wheel is grounded
	if throttle > 0 and _rear_grounded:
		var current_speed: float = linear_velocity.length()
		var speed_ratio: float = clamp(current_speed / max_speed, 0.0, 1.0)
		var accel_curve: float = 1.0 - (speed_ratio * speed_ratio * 0.6)  # Quadratic falloff

		# Project forward direction onto the ground plane for better slope climbing
		# This makes the force push ALONG the slope rather than INTO it
		var drive_forward: Vector3 = forward
		if _rear_normal.y < 0.99:  # Not perfectly flat
			# Project forward onto the plane defined by rear wheel's ground normal
			var ground_forward: Vector3 = (forward - _rear_normal * forward.dot(_rear_normal)).normalized()
			# Blend between bike forward and ground-aligned forward
			# More ground alignment at low speed (helps climbing), less at high speed (feels natural)
			var climb_blend: float = 1.0 - clamp(current_speed / 8.0, 0.0, 0.7)
			drive_forward = forward.lerp(ground_forward, climb_blend).normalized()

		var force_vec: Vector3 = drive_forward * throttle * engine_force * accel_curve
		# Apply force at wheel contact - creates natural wheelie torque!
		var force_pos: Vector3 = _rear_contact_point - global_position
		apply_force(force_vec, force_pos)

	# === BRAKE / REVERSE ===
	# Only brake when NOT throttling (so Shift+S = wheelie, not brake)
	if tilt < 0 and throttle == 0:
		var dominated_forward: float = linear_velocity.dot(forward)
		if dominated_forward > 1.0:
			# Moving forward - apply brakes
			var brake_dir: Vector3 = -linear_velocity.normalized()
			if _front_grounded:
				var force_pos: Vector3 = _front_contact_point - global_position
				apply_force(brake_dir * abs(tilt) * brake_force * 0.7, force_pos)
			if _rear_grounded:
				var force_pos: Vector3 = _rear_contact_point - global_position
				apply_force(brake_dir * abs(tilt) * brake_force * 0.3, force_pos)
		elif _rear_grounded:
			# Stopped or moving backward - apply reverse force (only when rear wheel grounded)
			var reverse_force: Vector3 = -forward * abs(tilt) * engine_force * 0.8
			var force_pos: Vector3 = _rear_contact_point - global_position
			apply_force(reverse_force, force_pos)

	# === STEERING & LEAN ===
	var is_grounded: bool = _front_grounded or _rear_grounded

	# Detect if moving backward (for steering inversion and visual lean)
	var moving_backward: bool = linear_velocity.dot(forward) < -0.5

	if is_grounded:
		# Ground steering - works at all speeds, boosted at low speed for tight turns
		var steer_torque_applied: Vector3 = Vector3.ZERO
		var current_speed: float = linear_velocity.length()

		# Reduce steering at high speed (prevents oversteer at speed)
		var high_speed_factor: float = 1.0 - (current_speed / max_speed) * steer_speed_factor
		high_speed_factor = clamp(high_speed_factor, 0.4, 1.0)

		# BOOST steering at low speed for tight turns (1.5x at standstill, 1.0x at 5+ m/s)
		var low_speed_boost: float = 1.0 + 0.5 * (1.0 - clamp(current_speed / 5.0, 0.0, 1.0))

		var speed_factor: float = high_speed_factor * low_speed_boost
		var throttle_boost: float = 1.0 + abs(throttle) * 0.5

		# Camera angle boost - how much camera is offset from bike facing
		var camera_offset: float = _camera_yaw - global_rotation.y
		# Normalize to [-PI, PI]
		while camera_offset > PI:
			camera_offset -= TAU
		while camera_offset < -PI:
			camera_offset += TAU

		# Boost turn power when steering toward where camera is looking
		var look_alignment: float = camera_offset * steer  # Positive when aligned
		var camera_boost: float = 1.0 + clamp(look_alignment, 0.0, 0.5)  # Up to 1.5x boost

		# Invert steering when moving backward (like a car in reverse)
		var effective_steer: float = -steer if moving_backward else steer

		# Reduce steering on steep slopes (friction makes turning hard)
		var slope_steer_factor: float = 1.0 - (slope_factor * 0.7)

		# Apply steering torque - grip physics handles the difference between normal and drift
		steer_torque_applied = Vector3.UP * effective_steer * steer_torque * speed_factor * throttle_boost * camera_boost * slope_steer_factor
		apply_torque(steer_torque_applied)

		# Ground lean control (Trials-style: W/S = tilt forward/back)
		# Use horizontal right vector to prevent yaw influence
		var horizontal_right: Vector3 = Vector3(right.x, 0, right.z).normalized()
		var lean_torque_applied: Vector3 = horizontal_right * tilt * lean_torque
		apply_torque(lean_torque_applied)

		# === ARCADE VELOCITY CONTROL ===
		if drifting:
			# DRIFT MODE: Physics-based sliding
			# Kickout when first entering drift - only if actively steering
			if not _was_drifting and linear_velocity.length() > 5.0:
				if abs(steer) > 0.1:
					# Scale kickout by steering intensity
					var kickout_strength: float = abs(steer) * drift_kickout * mass
					var kickout_impulse: Vector3 = right * -steer * kickout_strength
					apply_central_impulse(kickout_impulse)
				# Set camera delay for smooth transition
				_drift_camera_delay = 0.3

			# Drift grip - counter-force to lateral velocity for tighter turns
			var lateral_vel: float = linear_velocity.dot(right)
			if abs(lateral_vel) > 0.1:
				var grip_force: Vector3 = -right * lateral_vel * drift_grip
				apply_central_force(grip_force)

			# Boosted steering during drift for quick pivots
			var drift_steer_torque: Vector3 = Vector3.UP * steer * steer_torque * drift_steer_boost
			apply_torque(drift_steer_torque)
		else:
			# NORMAL MODE: Direct velocity alignment (snappy arcade feel)
			var speed: float = linear_velocity.length()
			if speed > 0.5:
				# Preserve speed, align direction to where bike is facing
				var forward_vel: float = linear_velocity.dot(forward)
				var target_vel: Vector3 = forward * forward_vel
				# Blend between current and aligned velocity
				# Reduce alignment when only one wheel grounded (wheelies, stoppies, landings)
				var both_wheels: bool = _front_grounded and _rear_grounded
				var align_strength: float = velocity_alignment if both_wheels else velocity_alignment * 0.3
				var align_factor: float = align_strength * 15.0 * delta  # Frame-rate independent
				linear_velocity.x = lerp(linear_velocity.x, target_vel.x, align_factor)
				linear_velocity.z = lerp(linear_velocity.z, target_vel.z, align_factor)

			# Direct yaw damping when not steering
			if abs(steer) < 0.1:
				var yaw_damp: float = 1.0 - (2.0 * delta)  # Frame-rate independent (~0.97 at 60fps)
				angular_velocity.y *= yaw_damp
	else:
		# === AIR CONTROL ===
		# Air pitch for flips (W/S) - very responsive
		apply_torque(right * tilt * air_pitch_torque)

		# Air yaw (A/D) - spin around bike's local up axis
		var up: Vector3 = global_transform.basis.y
		apply_torque(up * steer * air_yaw_torque)

	# Calculate speed for various uses
	var speed: float = linear_velocity.length()

	# Calculate visual lean for BikeModel (separate from physics)
	var target_visual_lean: float = 0.0
	# Only apply visual lean when BOTH wheels are grounded (not during wheelies)
	# Skip drift lean when reversing - only apply steering lean
	if _front_grounded and _rear_grounded and speed > 1.0:
		if not moving_backward:
			# Drift lean - lean OPPOSITE to slip angle (counter-steer visual)
			# This looks like the rider is leaning their body to counter the drift
			var vel_horizontal: Vector3 = Vector3(linear_velocity.x, 0, linear_velocity.z)
			# Use horizontal projection of forward to avoid issues when pitched
			var forward_horizontal: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
			if vel_horizontal.length() > 2.0 and forward_horizontal.length() > 0.1:
				var slip_angle: float = forward_horizontal.signed_angle_to(vel_horizontal.normalized(), Vector3.UP)
				# Counter-lean: positive multiplier = lean opposite to drift direction
				# Enhanced lean when drifting for more dramatic visual feedback
				var lean_multiplier: float = 2.5 if drifting else 1.5
				target_visual_lean = slip_angle * lean_multiplier
				target_visual_lean = clamp(target_visual_lean, -max_lean_angle, max_lean_angle)

		# Add steering lean on top (lean into the turn when steering)
		var steer_lean: float = -steer * 0.4
		target_visual_lean += steer_lean
		target_visual_lean = clamp(target_visual_lean, -max_lean_angle, max_lean_angle)

	# Smooth lean transitions
	var lean_speed: float = 12.0 if abs(target_visual_lean) < abs(_visual_lean) else 8.0
	_visual_lean = lerp(_visual_lean, target_visual_lean, lean_speed * delta)

	# Rear follows front with a natural delay (like a real bike)
	var rear_follow_speed: float = 6.0 * delta  # Slower follow for natural feel
	_rear_lean = lerp(_rear_lean, _visual_lean, rear_follow_speed)

	# Gentle pitch stabilization when grounded (helps balance)
	if is_grounded and abs(tilt) < 0.1:
		var current_pitch: float = global_rotation.x
		apply_torque(right * -current_pitch * pitch_stabilization)

	# === UPRIGHT STABILIZATION (arcade direct control) ===
	# Stabilize bike perpendicular to the SLOPE, not the world
	if is_grounded:
		# Get the ground normal (use rear wheel, fallback to front)
		var ground_normal: Vector3 = Vector3.UP
		if _rear_grounded:
			ground_normal = _rear_normal
		elif _front_grounded:
			ground_normal = _front_normal

		# Calculate target roll to be perpendicular to slope
		# But only when facing up/down the slope, not across it
		var target_roll: float = 0.0
		if slope_factor > 0.02:  # Adjust on even slight slopes
			# Get slope's downhill direction (horizontal component of normal, inverted)
			var slope_horizontal: Vector3 = Vector3(ground_normal.x, 0, ground_normal.z)
			if slope_horizontal.length() > 0.01:
				slope_horizontal = slope_horizontal.normalized()
				# How much are we facing up/down vs across the slope? (1 = up/down, 0 = across)
				var forward_horizontal: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
				var facing_slope: float = abs(forward_horizontal.dot(slope_horizontal))

				# Only apply slope roll when facing up/down the slope
				var slope_right_component: float = ground_normal.dot(right)
				target_roll = asin(clamp(-slope_right_component, -1.0, 1.0)) * facing_slope

		# Lerp roll toward slope-aligned orientation (faster on steeper slopes)
		var roll_lerp_speed: float = 0.3 + slope_factor * 0.4  # 0.3 flat, up to 0.7 on steep
		global_rotation.z = lerp(global_rotation.z, target_roll, roll_lerp_speed)

		# Kill roll angular velocity
		var horizontal_forward: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
		if horizontal_forward.length() > 0.1:
			var roll_ang_vel: float = angular_velocity.dot(horizontal_forward)
			angular_velocity -= horizontal_forward * roll_ang_vel * 0.5
	# No roll correction when airborne - allow full aerial freedom for flips

	# === SLOPE GRIP (extra stability on steep surfaces) ===
	if is_grounded and slope_factor > 0.1:
		# Dampen angular velocity more on slopes - resist flipping
		var slope_damp: float = slope_factor * 0.8
		angular_velocity *= (1.0 - slope_damp * delta * 15.0)

		# Reduce lateral velocity on slopes (friction keeps bike stuck to surface)
		var lateral_vel: float = linear_velocity.dot(right)
		linear_velocity -= right * lateral_vel * slope_factor * 0.5

		# Anti-slide: counter gravity's downhill pull to prevent unwanted sliding/turning
		var ground_normal: Vector3 = _rear_normal if _rear_grounded else _front_normal
		var downhill_dir: Vector3 = Vector3(ground_normal.x, 0, ground_normal.z).normalized()
		if downhill_dir.length() > 0.01:
			# Apply force uphill to counter gravity's downhill component
			var anti_slide_force: float = mass * 9.8 * slope_factor * 0.8
			apply_central_force(-downhill_dir * anti_slide_force)

	# === CLIMB ASSIST (front wheel on steep, rear on flat) ===
	if _front_grounded and _rear_grounded and throttle > 0:
		var front_slope: float = 1.0 - _front_normal.y
		var rear_slope: float = 1.0 - _rear_normal.y
		# If front wheel is on steeper surface than rear, help push up
		if front_slope > rear_slope + 0.1:
			# Add upward force to help climb over the edge
			var climb_assist: float = (front_slope - rear_slope) * engine_force * 0.3
			apply_central_force(Vector3.UP * climb_assist)

	# === SPEED CONTROL (arcade direct clamp) ===
	# Hard cap on speed - instant, responsive
	if speed > max_speed:
		linear_velocity = linear_velocity.normalized() * max_speed

	# === JUMP ===
	if Input.is_action_just_pressed("jump") and is_grounded:
		apply_central_impulse(Vector3.UP * jump_impulse)

	# === RESET (R key) ===
	if Input.is_physical_key_pressed(KEY_R):
		reset_in_place()

	# Track drift state for next frame (for kickout detection)
	_was_drifting = drifting

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
	# Handle mouse control decay with delay
	if _mouse_hold_timer > 0:
		_mouse_hold_timer -= delta
	else:
		# Gradually reduce mouse control strength - slow fade back to auto-follow
		# Takes ~1.5 seconds to fully return to auto-follow (0.7 per second decay)
		_mouse_control_strength = maxf(0.0, _mouse_control_strength - 0.7 * delta)

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

	# Auto-follow camera (blended with mouse control)
	# Get horizontal direction - prefer velocity when moving, else bike forward
	var horiz_vel: Vector3 = Vector3(linear_velocity.x, 0, linear_velocity.z)
	var horiz_speed: float = horiz_vel.length()

	# Check if bike is upright (not mid-flip) - up vector should point mostly up
	var bike_upright: bool = global_transform.basis.y.y > 0.5

	# Determine target yaw for auto-follow
	var target_yaw: float = _camera_yaw  # Default: maintain current
	var should_update: bool = false

	if is_grounded and bike_upright:
		if horiz_speed > 2.0:
			# Moving on ground - follow velocity direction
			target_yaw = atan2(horiz_vel.x, horiz_vel.z)
			should_update = true
		else:
			# Slow/stopped on ground - follow bike's forward
			var fwd: Vector3 = global_transform.basis.z
			var horizontal_dir: Vector3 = Vector3(fwd.x, 0, fwd.z)
			if horizontal_dir.length() > 0.1:
				horizontal_dir = horizontal_dir.normalized()
				target_yaw = atan2(horizontal_dir.x, horizontal_dir.z)
				should_update = true
	elif horiz_speed > 8.0:
		# Moving fast horizontally - follow velocity regardless of orientation
		target_yaw = atan2(horiz_vel.x, horiz_vel.z)
		should_update = true
	# else: maintain current camera yaw during tricks/flips or when not upright

	if should_update:
		# Camera speed - during drift entry, scale by angle difference
		var camera_speed: float = 6.0
		if _drift_camera_delay > 0:
			# Scale speed by angle: small angle = slow (2.0), big angle = fast (6.0)
			var angle_diff: float = abs(angle_difference(_camera_yaw, target_yaw))
			camera_speed = lerpf(2.0, 6.0, clampf(angle_diff / PI, 0.0, 1.0))
			_drift_camera_delay -= delta

		# Blend auto-follow with mouse control
		# When mouse_control_strength is 1.0, no auto-follow
		# When mouse_control_strength is 0.0, full auto-follow
		var effective_speed: float = camera_speed * (1.0 - _mouse_control_strength)
		_camera_yaw = lerp_angle(_camera_yaw, target_yaw, effective_speed * delta)

	# Always keep camera upright (only rotate on Y axis)
	_camera_pivot.rotation = Vector3(0, _camera_yaw, 0)


func _animate_bike(delta: float) -> void:
	if not _bike_model:
		return

	if not disable_visual_effects:
		# Apply visual lean - rear follows front naturally
		# BikeModel gets the delayed rear lean
		_bike_model.rotation.z = _rear_lean
		# Front assembly gets extra rotation so it leads (difference between front and rear)
		if _front_assembly:
			_front_assembly.rotation.z = _visual_lean - _rear_lean

		# Apply landing squash effect (compress Y, expand X/Z)
		_bike_model.scale.y = 1.0 - _landing_squash
		_bike_model.scale.x = 1.0 + _landing_squash * 0.5
		_bike_model.scale.z = 1.0 + _landing_squash * 0.5
	else:
		# Reset to neutral - show raw physics body position
		_bike_model.rotation.z = 0.0
		if _front_assembly:
			_front_assembly.rotation.z = 0.0
		_bike_model.scale = Vector3.ONE

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

	# Pedal animation when throttle is held
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
	_rear_lean = 0.0
	_landing_squash = 0.0
	_was_airborne = false
	if _bike_model:
		_bike_model.rotation.z = 0.0
	if _front_assembly:
		_front_assembly.rotation.z = 0.0
		_bike_model.scale = Vector3.ONE


func reset_in_place() -> void:
	# Keep X and Z position, lift slightly off ground, reset rotation and velocities
	global_position = Vector3(global_position.x, global_position.y + 1.0, global_position.z)
	global_rotation = Vector3.ZERO
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_wheel_rotation = 0.0
	_steering_angle = 0.0
	_visual_lean = 0.0
	_rear_lean = 0.0
	_landing_squash = 0.0
	_was_airborne = false
	# Reset camera to face bike's forward direction
	_camera_yaw = global_rotation.y
	if _bike_model:
		_bike_model.rotation.z = 0.0
		_bike_model.scale = Vector3.ONE
	if _front_assembly:
		_front_assembly.rotation.z = 0.0
