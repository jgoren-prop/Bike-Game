extends RigidBody3D
class_name BikeController

## Trials-Style Bike Controller using RigidBody3D
## Real physics-based movement with wheelies, stoppies, and full rotation

# === STABILITY MODE STATE MACHINE ===
enum StabilityMode { AIR, NORMAL_GROUNDED, STEEP_SIDEWAYS, CRASH_WINDOW }

# === PHYSICS PARAMETERS ===
# Movement
@export var engine_force: float = 2100.0     # Forward thrust (Newtons)
@export var brake_force: float = 1000.0      # Braking force (snappy stops)
@export var max_speed: float = 21.0          # Engine-limited speed on flat ground (m/s)
@export var downhill_speed_bonus: float = 1.5 # Multiplier for max speed when going downhill (gravity assist)

# Momentum
@export var bike_mass: float = 95.0          # Mass (kg)
@export var bike_drag: float = 0.08          # Linear damping - lower for smoother landings

# Steering
@export var steer_torque: float = 250.0      # Yaw torque for turning
@export var steer_speed_factor: float = 0.4  # Less steering at high speed

# Balance/Lean (W = throttle + tilt forward, S = brake/tilt back)
@export var lean_torque: float = 400.0       # Pitch torque from input
@export var pitch_stabilization: float = 120.0 # Pitch stability when grounded

# Arcade Handling - NEW TRACTION MODEL (replaces velocity_alignment)
@export var traction_accel_time: float = 0.15      # Seconds to reach target speed
@export var lateral_grip_strength: float = 12.0    # Lateral damping multiplier (normal mode)
@export var drift_lateral_grip: float = 2.0        # Lower grip during drift
@export var max_traction_force: float = 3000.0     # Safety clamp for seam transitions
@export var drift_kickout: float = 0.0       # Lateral impulse when starting drift
@export var drift_steer_boost: float = 1.3   # Steering multiplier during drift
@export var max_lean_angle: float = 0.6      # ~35 degrees max lean (radians)

# Torque-Based Stabilization (see Per-Mode Stabilization Strengths for main params)
@export var lean_into_turn_angle: float = 0.15       # Radians (~8.5 degrees) - how much bike leans into turns
@export var max_stabilization_torque: float = 800.0  # Hard clamp for safety
@export var min_lean_speed: float = 2.0              # No lean below this speed

# Anti-Slide (replaces direct lateral velocity deletion)
@export var anti_slide_strength: float = 0.8  # 0-1, how much of gravity's downhill pull to counter

# Ground Probing
@export var normal_smoothing_base: int = 5   # Frames at low speed (~42ms at 120Hz)
@export var normal_smoothing_min: int = 2    # Frames at high speed (~17ms)

# Legacy Systems (behind toggles for testing)
@export var enable_legacy_bump_assist: bool = false
@export var enable_legacy_climb_assist: bool = false

# Jump
@export var jump_impulse: float = 600.0      # Impulse when jumping (perpendicular to bike bottom)

# Arcade Feel Parameters
@export var angular_damping_value: float = 0.8  # Angular damping (rotation resistance)
@export var air_pitch_torque: float = 350.0   # Air flip responsiveness
@export var air_yaw_torque: float = 180.0      # Air spin responsiveness
@export var fov_boost: float = 1.0            # Max FOV increase at top speed
@export var landing_squash_amount: float = 0.10  # Visual squash on landing
@export var disable_visual_effects: bool = false  # Debug: disable visual lean/squash

# Camera Parameters
@export var base_fov: float = 65.0            # Base field of view
@export var camera_distance: float = 5.5      # Distance behind bike
@export var camera_height: float = 3.0        # Height above bike
@export var camera_angle: float = 16.0        # Pitch angle (degrees) - how much camera looks down

# Suspension Parameters
@export var suspension_stiffness: float = 60.0    # Spring force (N/m) - softer for better landings
@export var suspension_damping: float = 40.0      # Damper to prevent oscillation - lower for more bounce
@export var suspension_rest_length: float = 0.55  # Neutral suspension position
@export var max_suspension_travel: float = 0.35   # Max compression/extension - more travel for hard landings

# Tire Grip Parameters
@export var tire_grip: float = 5.00               # How well tires climb obstacles (0 = no grip, 5+ = very sticky)
@export var front_climb_force: float = 1200.0     # Force to help front wheel climb bumps (needs to exceed bike weight)
@export var bump_pop_strength: float = 0.3        # How strong the "pop" assist is when stuck on bumps (0-1)

# Wall Grip Parameters (speed-dependent stability on angled walls)
@export var wall_grip_speed_threshold: float = 9.0  # Speed (m/s) for full wall grip; below this, bike tips on steep sideways walls

# Stability Mode Thresholds
@export var steep_slope_threshold: float = 0.5       # ground_up.y below this = steep (~60 degrees)
@export var across_slope_threshold: float = 0.7     # across_factor above this = sideways
@export var sideways_speed_threshold: float = 4.0   # Speed below this + steep + sideways = can fall
@export var crash_impact_threshold: float = 15.0    # Impulse magnitude to trigger crash window
@export var crash_window_duration: float = 0.5      # Seconds of reduced stabilization after impact

# Per-Mode Stabilization Strengths
@export var normal_upright_strength: float = 500.0  # Strong for normal driving (never fall)
@export var normal_roll_damping: float = 15.0       # High damping on flat ground
@export var steep_upright_strength: float = 80.0    # Weak when sideways on steep slope
@export var steep_roll_damping: float = 2.0         # Low damping allows falling

# COM Shifting (lowers center of mass when grounded for stability)
@export var grounded_com_offset: float = -0.15      # Lower COM when grounded (negative = down)

# === INTERNAL STATE ===
var _front_grounded: bool = false
var _rear_grounded: bool = false
var _front_contact_point: Vector3
var _rear_contact_point: Vector3
var _front_normal: Vector3 = Vector3.UP
var _rear_normal: Vector3 = Vector3.UP

# Normal smoothing buffers
var _front_normal_buffer: Array[Vector3] = []
var _rear_normal_buffer: Array[Vector3] = []
var _smoothed_front_normal: Vector3 = Vector3.UP
var _smoothed_rear_normal: Vector3 = Vector3.UP

# Ground frame (computed each physics tick)
var _ground_up: Vector3 = Vector3.UP
var _ground_forward: Vector3 = Vector3.FORWARD
var _ground_right: Vector3 = Vector3.RIGHT
var _is_grounded: bool = false
var _surface_velocity: Vector3 = Vector3.ZERO
var _relative_velocity: Vector3 = Vector3.ZERO

# Stability state machine
var _stability_mode: StabilityMode = StabilityMode.AIR
var _crash_window_timer: float = 0.0
var _prev_velocity: Vector3 = Vector3.ZERO  # For impact detection
var _across_slope_factor: float = 0.0       # Cached for debug/display

# Platform velocity tracking
var _platform_prev_pos: Dictionary = {}  # node_id -> Vector3

# Suspension state
var _front_suspension_compression: float = 0.0  # Current compression (0 = rest, positive = compressed)
var _rear_suspension_compression: float = 0.0
var _front_wheel_visual_offset: float = 0.0     # Visual offset for wheel position
var _rear_wheel_visual_offset: float = 0.0
var _prev_front_compression: float = 0.0        # For velocity calculation
var _prev_rear_compression: float = 0.0


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
var _landing_grace_timer: float = 0.0  # Reduces alignment right after landing


# Node references
@onready var _bike_model: Node3D = $BikeModel
@onready var _front_assembly: Node3D = $BikeModel/FrontAssembly
@onready var _front_wheel: Node3D = $BikeModel/FrontAssembly/FrontWheel
@onready var _rear_wheel: Node3D = $BikeModel/RearWheel
@onready var _pedal_arm_left: MeshInstance3D = $BikeModel/PedalArmLeft
@onready var _pedal_arm_right: MeshInstance3D = $BikeModel/PedalArmRight
@onready var _camera_pivot: Node3D = $CameraPivot
@onready var _camera: Camera3D = $CameraPivot/Camera3D
@onready var _front_wheel_probe: ShapeCast3D = $FrontWheelProbe
@onready var _rear_wheel_probe: ShapeCast3D = $RearWheelProbe

signal speed_changed(speed: float)


var _bump_assist_active: bool = false  # Track if we're currently assisting a bump climb

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Compute ground frame FIRST - all other physics uses this
	_compute_ground_frame(state)
	
	# Update stability state machine (determines stabilization behavior)
	_update_stability_mode(state)
	
	# Get input for physics
	var throttle: float = 1.0 if Input.is_action_pressed("accelerate") else 0.0
	var brake: float = 1.0 if Input.is_action_pressed("brake") else 0.0
	var steer: float = Input.get_axis("steer_right", "steer_left")
	var drifting: bool = Input.is_physical_key_pressed(KEY_SHIFT)
	
	# === NEW TRACTION MODEL (Phase 3) ===
	# Force-based traction in ground frame - fixes slope traversal
	_apply_traction(state, throttle, brake, drifting)
	
	# === TORQUE-BASED STABILIZATION (Phase 4) ===
	# Replaces direct global_rotation writes - works WITH the physics solver
	_apply_stabilization(state, steer)
	
	# === ROLL DAMPING ===
	# Prevents roll velocity accumulation from small bumps
	_apply_roll_damping(state)
	
	# === ANTI-SLIDE (Phase 6) ===
	# Counters gravity's downhill pull without deleting player-intended lateral motion
	_apply_anti_slide(state)
	
	# === LEGACY BUMP ASSIST (behind toggle) ===
	_bump_assist_active = false
	if enable_legacy_bump_assist:
		if throttle > 0:
			var dominated_forward: Vector3 = global_transform.basis.z
			var forward_vel: float = state.linear_velocity.dot(dominated_forward)
			
			# Only assist when moving slowly (stuck)
			if forward_vel <= 3.0:
				# Check contacts for blocking obstacles
				for i in state.get_contact_count():
					var contact_normal: Vector3 = state.get_contact_local_normal(i)
					var blocking: float = -contact_normal.dot(dominated_forward)
					var steepness: float = 1.0 - abs(contact_normal.y)
					
					if blocking > 0.2 and steepness > 0.2:
						_bump_assist_active = true
						break


func _ready() -> void:
	# Apply RigidBody3D physics properties from exported vars
	mass = bike_mass
	linear_damp = bike_drag
	angular_damp = angular_damping_value
	
	# Enable custom center of mass so we can shift it dynamically for stability
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO  # Start at geometric center
	
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Make camera independent of bike rotation (won't flip when bike flips)
	_camera_pivot.top_level = true
	_camera_pivot.global_position = global_position + Vector3(0, 1, 0)
	_camera_pivot.rotation.y = _camera_yaw
	
	# Ensure lean_back input exists (in case project.godot wasn't reloaded)
	if not InputMap.has_action("lean_back"):
		InputMap.add_action("lean_back")
		var key_event := InputEventKey.new()
		key_event.physical_keycode = KEY_Q
		InputMap.action_add_event("lean_back", key_event)


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
	_apply_suspension(delta)
	_update_center_of_mass(delta)

	var throttle: float = 1.0 if Input.is_action_pressed("accelerate") else 0.0
	var tilt: float = Input.get_axis("brake", "accelerate")  # W = throttle + tilt, S = brake + tilt back
	var steer: float = Input.get_axis("steer_right", "steer_left")
	var drifting: bool = Input.is_physical_key_pressed(KEY_SHIFT)  # Shift = drift mode
	var lean_back: float = 1.0 if Input.is_action_pressed("lean_back") else 0.0  # Q = lean back for wheelies

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
	var wheels_touching: bool = _front_grounded or _rear_grounded

	# Detect if moving backward (for steering inversion and visual lean)
	var moving_backward: bool = linear_velocity.dot(forward) < -0.5

	if wheels_touching:
		# Ground steering - requires either throttle/brake input OR already moving
		var current_speed: float = linear_velocity.length()
		
		# Only allow steering when throttling, braking, or already moving
		# This prevents the bike from pivoting in place without any input
		var can_steer: bool = throttle > 0 or tilt < 0 or current_speed > 0.5
		
		# Apply steering torque (either normal OR drift, not both)
		if can_steer and abs(steer) > 0.01 and not drifting:
			var steer_torque_applied: Vector3 = Vector3.ZERO

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

			# Use ground-normal steering axis when grounded (Phase 5)
			# This prevents weird steering on slopes
			var steering_up: Vector3 = Vector3.UP
			if _rear_grounded:
				steering_up = _smoothed_rear_normal
			elif _front_grounded:
				steering_up = _smoothed_front_normal

			# Apply steering torque - normal mode only (drift has its own steering below)
			steer_torque_applied = steering_up * effective_steer * steer_torque * speed_factor * throttle_boost * camera_boost * slope_steer_factor
			apply_torque(steer_torque_applied)

		# Ground lean control (Trials-style: W/S = tilt forward/back)
		# Use horizontal right vector to prevent yaw influence
		var horizontal_right: Vector3 = Vector3(right.x, 0, right.z).normalized()
		
		# When bump assist is active, DISABLE forward lean from W key
		# Otherwise the forward lean fights the wheelie we're trying to do
		if not _bump_assist_active:
			var lean_torque_applied: Vector3 = horizontal_right * tilt * lean_torque
			apply_torque(lean_torque_applied)
		
		# Q key lean back for wheelies (independent of throttle/brake tilt)
		# Needs to overcome: forward lean from W (+200) + pitch stabilization
		# Negative direction = lean backward (same as S tilt direction)
		if lean_back > 0:
			var wheelie_torque: Vector3 = horizontal_right * -lean_back * lean_torque * 4.0
			apply_torque(wheelie_torque)
		
		# Bump assist: when stuck on a bump, apply UPWARD force at front wheel
		# This lifts the front wheel directly AND creates pitch-up torque
		if _bump_assist_active and throttle > 0:
			# Apply upward force at front wheel position
			# Front wheel is at local Z = 0.65 (from bike.tscn)
			var front_wheel_offset: Vector3 = global_transform.basis * Vector3(0, 0, 0.65)
			var lift_force: Vector3 = Vector3.UP * bump_pop_strength * 800.0
			apply_force(lift_force, front_wheel_offset)
			
			# Also apply the wheelie torque for extra rotation
			var bump_wheelie: Vector3 = horizontal_right * -bump_pop_strength * lean_torque * 2.0
			apply_torque(bump_wheelie)

		# === ARCADE VELOCITY CONTROL ===
		if drifting:
			# DRIFT MODE: Physics-based sliding
			# Kickout when first entering drift - only if actively steering
			if not _was_drifting and linear_velocity.length() > 5.0:
				if abs(steer) > 0.1:
					# Scale kickout by steering intensity
					var kickout_strength: float = abs(steer) * drift_kickout * mass
					# Use ground-frame right for kickout (Phase 7)
					var drift_ground_up: Vector3 = _smoothed_rear_normal if _rear_grounded else (_smoothed_front_normal if _front_grounded else Vector3.UP)
					var drift_ground_fwd: Vector3 = (forward - drift_ground_up * forward.dot(drift_ground_up))
					if drift_ground_fwd.length() > 0.1:
						drift_ground_fwd = drift_ground_fwd.normalized()
					var drift_ground_right: Vector3 = drift_ground_fwd.cross(drift_ground_up).normalized()
					var kickout_impulse: Vector3 = drift_ground_right * -steer * kickout_strength
					apply_central_impulse(kickout_impulse)
				# Set camera delay for smooth transition
				_drift_camera_delay = 0.3

			# Drift grip - counter-force to lateral velocity for tighter turns
			var lateral_vel: float = linear_velocity.dot(right)
			if abs(lateral_vel) > 0.1:
				var grip_force: Vector3 = -right * lateral_vel * drift_lateral_grip
				apply_central_force(grip_force)

			# Boosted steering during drift for quick pivots
			# Use ground-normal steering axis (Phase 5)
			var drift_steering_up: Vector3 = Vector3.UP
			if _rear_grounded:
				drift_steering_up = _smoothed_rear_normal
			elif _front_grounded:
				drift_steering_up = _smoothed_front_normal
			var drift_steer_torque: Vector3 = drift_steering_up * steer * steer_torque * drift_steer_boost
			apply_torque(drift_steer_torque)
		else:
			# NORMAL MODE: Traction handled in _integrate_forces (Phase 3)
			# OLD velocity alignment code removed - was causing slope traversal issues
			
			# Direct yaw damping when not steering (temporary, will be reviewed in Phase 3)
			if abs(steer) < 0.1:
				var yaw_damp: float = 1.0 - (2.0 * delta)  # Frame-rate independent (~0.97 at 60fps)
				angular_velocity.y *= yaw_damp
	else:
		# === AIR CONTROL ===
		# Air pitch for flips (W/S) - very responsive
		apply_torque(right * tilt * air_pitch_torque)
		
		# Q key lean back in air (for backflips)
		if lean_back > 0:
			apply_torque(right * -lean_back * air_pitch_torque)

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
	# Disabled when leaning (tilt), doing wheelie (lean_back), bump assist, or just landed
	if wheels_touching and abs(tilt) < 0.1 and lean_back < 0.1 and not _bump_assist_active and _landing_grace_timer <= 0:
		var current_pitch: float = global_rotation.x
		apply_torque(right * -current_pitch * pitch_stabilization)

	# === UPRIGHT STABILIZATION ===
	# MOVED TO _integrate_forces() -> _apply_stabilization()
	# Old code directly wrote to global_rotation.z which fought the physics solver.
	# New code uses torque-based stabilization that works WITH the solver.

	# === SLOPE GRIP ===
	# MOVED TO _integrate_forces() -> _apply_traction() and _apply_anti_slide()
	# Old code directly deleted lateral velocity which broke sideways ramp traversal.
	# New system uses ground-frame traction forces and gravity-countering anti-slide.

	# === CLIMB ASSIST (behind toggle) ===
	if enable_legacy_climb_assist and _front_grounded and _rear_grounded and throttle > 0:
		var front_slope: float = 1.0 - _front_normal.y
		var rear_slope: float = 1.0 - _rear_normal.y
		# If front wheel is on steeper surface than rear, help push up
		if front_slope > rear_slope + 0.1:
			# Add upward force to help climb over the edge
			var climb_assist: float = (front_slope - rear_slope) * engine_force * 0.3
			apply_central_force(Vector3.UP * climb_assist)

	# === SPEED CONTROL (slope-aware) ===
	# On flat/uphill: cap at max_speed (engine limit)
	# On downhill: allow gravity to push beyond max_speed up to a soft cap
	var effective_max_speed: float = max_speed
	
	# Calculate if we're going downhill (gravity is helping)
	# Downhill = velocity direction has a negative Y component when projected onto ground plane
	var downhill_factor: float = 0.0
	if wheels_touching and speed > 0.5:
		# Get ground normal
		var ground_normal: Vector3 = Vector3.UP
		if _rear_grounded:
			ground_normal = _rear_normal
		elif _front_grounded:
			ground_normal = _front_normal
		
		# Check if velocity is going "downhill" relative to the slope
		# Project velocity onto ground plane and see if it points down the slope
		var slope_dir: Vector3 = Vector3(ground_normal.x, 0, ground_normal.z)
		if slope_dir.length() > 0.01:
			slope_dir = slope_dir.normalized()
			var vel_horizontal: Vector3 = Vector3(linear_velocity.x, 0, linear_velocity.z).normalized()
			# Positive dot = moving down the slope (in direction gravity pulls)
			var slope_alignment: float = vel_horizontal.dot(slope_dir)
			# Also factor in how steep the slope is (steeper = more gravity assist)
			var slope_steepness: float = 1.0 - ground_normal.y  # 0 = flat, 1 = vertical
			downhill_factor = maxf(0.0, slope_alignment) * slope_steepness
	
	# Increase max speed when going downhill (gravity assist)
	effective_max_speed = max_speed + (max_speed * (downhill_speed_bonus - 1.0) * downhill_factor)
	
	# Soft speed limiting: only apply engine cap when throttling on flat/uphill
	# When going downhill without throttle, let gravity do its thing with higher cap
	if throttle > 0 and downhill_factor < 0.1:
		# Throttling on flat/uphill: hard cap at engine max_speed
		if speed > max_speed:
			linear_velocity = linear_velocity.normalized() * max_speed
	elif speed > effective_max_speed:
		# Downhill or coasting: soft cap at effective max (allows gravity boost)
		linear_velocity = linear_velocity.normalized() * effective_max_speed

	# === JUMP ===
	# Jump pushes away from bike's bottom (local UP), so angling bike up = more vertical jump
	if Input.is_action_just_pressed("jump") and wheels_touching:
		var jump_direction: Vector3 = global_transform.basis.y  # Bike's local up vector
		apply_central_impulse(jump_direction * jump_impulse)

	# === RESET (R key) ===
	if Input.is_physical_key_pressed(KEY_R):
		reset_in_place()

	# Track drift state for next frame (for kickout detection)
	_was_drifting = drifting

	# === LANDING IMPACT FEEL ===
	if wheels_touching and _was_airborne:
		# Just landed - trigger squash and grace period!
		_landing_squash = landing_squash_amount
		_landing_grace_timer = 0.3  # 300ms of reduced alignment for smooth landing
	_was_airborne = not wheels_touching

	# Recover from squash quickly
	_landing_squash = lerp(_landing_squash, 0.0, 10.0 * delta)
	
	# Tick down landing grace timer
	if _landing_grace_timer > 0:
		_landing_grace_timer -= delta

	# === CAMERA ===
	_update_camera(delta)

	# === ANIMATION ===
	_animate_bike(delta)

	# Emit speed
	speed_changed.emit(get_current_speed())


func _check_ground() -> void:
	# Calculate speed-adaptive smoothing window
	var current_speed: float = linear_velocity.length()
	var speed_ratio: float = clampf(current_speed / max_speed, 0.0, 1.0)
	var smoothing_frames: int = int(lerpf(float(normal_smoothing_base), float(normal_smoothing_min), speed_ratio))
	
	# Front wheel probe (ShapeCast3D)
	var was_front_grounded: bool = _front_grounded
	_front_grounded = _front_wheel_probe.is_colliding()
	if _front_grounded:
		_front_contact_point = _front_wheel_probe.get_collision_point(0)
		_front_normal = _front_wheel_probe.get_collision_normal(0)
		
		# Add to normal buffer for smoothing
		_front_normal_buffer.append(_front_normal)
		if _front_normal_buffer.size() > smoothing_frames:
			_front_normal_buffer.pop_front()
		
		# Compute smoothed normal (average of buffer)
		_smoothed_front_normal = _compute_smoothed_normal(_front_normal_buffer)
	else:
		# Just left ground - flush buffer to prevent stale normals
		if was_front_grounded:
			_front_normal_buffer.clear()
		_smoothed_front_normal = _smoothed_front_normal.lerp(Vector3.UP, 0.3)

	# Rear wheel probe (ShapeCast3D)
	var was_rear_grounded: bool = _rear_grounded
	_rear_grounded = _rear_wheel_probe.is_colliding()
	if _rear_grounded:
		_rear_contact_point = _rear_wheel_probe.get_collision_point(0)
		_rear_normal = _rear_wheel_probe.get_collision_normal(0)
		
		# Add to normal buffer for smoothing
		_rear_normal_buffer.append(_rear_normal)
		if _rear_normal_buffer.size() > smoothing_frames:
			_rear_normal_buffer.pop_front()
		
		# Compute smoothed normal (average of buffer)
		_smoothed_rear_normal = _compute_smoothed_normal(_rear_normal_buffer)
	else:
		# Just left ground - flush buffer to prevent stale normals
		if was_rear_grounded:
			_rear_normal_buffer.clear()
		_smoothed_rear_normal = _smoothed_rear_normal.lerp(Vector3.UP, 0.3)


func _compute_smoothed_normal(buffer: Array[Vector3]) -> Vector3:
	if buffer.is_empty():
		return Vector3.UP
	
	var sum: Vector3 = Vector3.ZERO
	for normal in buffer:
		sum += normal
	
	return (sum / float(buffer.size())).normalized()


func _compute_ground_frame(state: PhysicsDirectBodyState3D) -> void:
	## Compute ground-relative coordinate frame for all grounded physics.
	## Must be called at start of _integrate_forces for coherent data.
	
	if not _front_grounded and not _rear_grounded:
		_is_grounded = false
		# Blend to world up when airborne (don't use stale normal)
		_ground_up = _ground_up.lerp(Vector3.UP, 0.3)
		_surface_velocity = Vector3.ZERO
		_relative_velocity = state.linear_velocity
		return
	
	_is_grounded = true
	
	# Get surface velocity for platform support
	_surface_velocity = _get_surface_velocity()
	_relative_velocity = state.linear_velocity - _surface_velocity
	
	# Blend normals: favor rear when both grounded
	var blended_normal: Vector3
	if _front_grounded and _rear_grounded:
		blended_normal = (_smoothed_rear_normal * 0.7 + _smoothed_front_normal * 0.3).normalized()
	elif _rear_grounded:
		blended_normal = _smoothed_rear_normal
	else:
		blended_normal = _smoothed_front_normal
	
	_ground_up = blended_normal
	
	# Project bike forward onto ground plane
	# NOTE: +Z is forward in this codebase (front wheel at Z=+0.65)
	var bike_forward: Vector3 = global_transform.basis.z
	var projected: Vector3 = bike_forward - _ground_up * bike_forward.dot(_ground_up)
	
	# Check projection stability (bike nearly perpendicular to slope)
	if projected.length() < 0.3:
		# Fallback: use world-horizontal projection
		projected = Vector3(bike_forward.x, 0, bike_forward.z)
		if projected.length() < 0.1:
			# Bike is nearly vertical - keep last valid ground_forward
			return
	
	_ground_forward = projected.normalized()
	
	# Right-handed basis: forward × up = right
	_ground_right = _ground_forward.cross(_ground_up).normalized()


func _get_surface_velocity() -> Vector3:
	## Get velocity of the surface we're standing on (for moving platforms).
	## Returns Vector3.ZERO for static surfaces.
	
	if not _front_grounded and not _rear_grounded:
		return Vector3.ZERO
	
	# Get the collider from probe (prefer rear)
	var probe: ShapeCast3D = _rear_wheel_probe if _rear_grounded else _front_wheel_probe
	if probe.get_collision_count() == 0:
		return Vector3.ZERO
	
	var collider: Object = probe.get_collider(0)
	if collider == null:
		return Vector3.ZERO
	
	# Static bodies have zero velocity
	if collider is StaticBody3D:
		return Vector3.ZERO
	
	# For AnimatableBody3D / RigidBody3D, compute from position delta
	var node: Node3D = collider as Node3D
	if node == null:
		return Vector3.ZERO
	
	var node_id: int = node.get_instance_id()
	var current_pos: Vector3 = node.global_position
	var dt: float = get_physics_process_delta_time()
	
	if not _platform_prev_pos.has(node_id):
		_platform_prev_pos[node_id] = current_pos
		return Vector3.ZERO
	
	var prev_pos: Vector3 = _platform_prev_pos[node_id]
	_platform_prev_pos[node_id] = current_pos
	
	# Clean up old entries (platforms we're no longer on)
	if _platform_prev_pos.size() > 5:
		_platform_prev_pos.clear()
		_platform_prev_pos[node_id] = current_pos
	
	return (current_pos - prev_pos) / dt


func _compute_across_slope_factor() -> float:
	## Compute how much the bike is moving ACROSS the slope (perpendicular to downhill).
	## Returns 0.0 when moving up/down slope, 1.0 when moving perfectly sideways.
	
	if not _is_grounded:
		return 0.0
	
	# Downhill direction = gravity projected onto slope plane
	var gravity_slope: Vector3 = Vector3.DOWN - _ground_up * Vector3.DOWN.dot(_ground_up)
	if gravity_slope.length() < 0.1:
		return 0.0  # Flat ground - no "across slope" concept
	
	var downhill_dir: Vector3 = gravity_slope.normalized()
	
	# Check if velocity/heading is perpendicular to downhill
	if _relative_velocity.length() < 0.5:
		# Use bike heading when nearly stationary
		var bike_forward: Vector3 = global_transform.basis.z
		var heading_projected: Vector3 = bike_forward - _ground_up * bike_forward.dot(_ground_up)
		if heading_projected.length() < 0.1:
			return 0.0
		var heading_dir: Vector3 = heading_projected.normalized()
		var alignment: float = absf(heading_dir.dot(downhill_dir))
		return 1.0 - alignment
	else:
		# Use velocity direction when moving
		var move_dir: Vector3 = _relative_velocity.normalized()
		var alignment: float = absf(move_dir.dot(downhill_dir))
		# 0 = moving down/up slope, 1 = moving across slope
		return 1.0 - alignment


func _update_stability_mode(state: PhysicsDirectBodyState3D) -> void:
	## Update the stability state machine based on current conditions.
	## Called at the start of _integrate_forces after ground frame is computed.
	
	var delta: float = state.step
	
	# Tick down crash window timer
	if _crash_window_timer > 0:
		_crash_window_timer -= delta
	
	# === IMPACT DETECTION ===
	# Check for sudden velocity change indicating a big hit
	var velocity_delta: Vector3 = state.linear_velocity - _prev_velocity
	var impact_magnitude: float = velocity_delta.length() / delta  # Approximate acceleration
	_prev_velocity = state.linear_velocity
	
	if impact_magnitude > crash_impact_threshold * 100.0:  # Scale by mass-ish factor
		_crash_window_timer = crash_window_duration
		_stability_mode = StabilityMode.CRASH_WINDOW
		return
	
	# === CRASH WINDOW ACTIVE ===
	if _crash_window_timer > 0:
		_stability_mode = StabilityMode.CRASH_WINDOW
		return
	
	# === AIR CHECK ===
	if not _is_grounded:
		_stability_mode = StabilityMode.AIR
		return
	
	# === GROUNDED: Check for STEEP_SIDEWAYS conditions ===
	var is_steep: bool = _ground_up.y < steep_slope_threshold
	
	_across_slope_factor = _compute_across_slope_factor()
	var is_across: bool = _across_slope_factor > across_slope_threshold
	
	var relative_speed: float = _relative_velocity.length()
	var is_slow: bool = relative_speed < sideways_speed_threshold
	
	# STEEP_SIDEWAYS: All three conditions must be true
	if is_steep and is_across and is_slow:
		_stability_mode = StabilityMode.STEEP_SIDEWAYS
	else:
		_stability_mode = StabilityMode.NORMAL_GROUNDED


func _apply_anti_slide(state: PhysicsDirectBodyState3D) -> void:
	## Apply uphill force to counter gravity's downhill pull on slopes.
	## Replaces the old lateral velocity deletion which broke sideways traversal.
	
	if not _is_grounded:
		return
	
	# Project world gravity onto slope plane
	var gravity_world: Vector3 = Vector3.DOWN * 9.8 * mass
	var gravity_normal_component: float = gravity_world.dot(_ground_up)
	var gravity_slope: Vector3 = gravity_world - _ground_up * gravity_normal_component
	
	# Skip if slope is nearly flat
	if gravity_slope.length() < 0.1:
		return
	
	# Speed gate using RELATIVE velocity (consistent with traction, works on platforms)
	var relative_speed: float = _relative_velocity.length()
	var speed_gate: float = clampf(relative_speed / (wall_grip_speed_threshold * 0.2), 0.0, 1.0)
	
	# Counter-force pointing uphill
	var anti_slide_force: Vector3 = -gravity_slope * anti_slide_strength * speed_gate
	
	state.apply_central_force(anti_slide_force)


func _apply_stabilization(state: PhysicsDirectBodyState3D, steer_input: float) -> void:
	## Apply torque-based upright stabilization based on current stability mode.
	## Uses mode-specific strength: strong for normal driving, weak when sideways on slopes.
	
	# === MODE-BASED EARLY EXIT ===
	# AIR: No stabilization - player has full control for tricks
	# CRASH_WINDOW: Minimal stabilization - let physics play out
	if _stability_mode == StabilityMode.AIR:
		return
	
	if _stability_mode == StabilityMode.CRASH_WINDOW:
		# Apply very weak stabilization during crash window (10% of steep strength)
		# This prevents instant recovery but still provides some damping
		pass  # Continue with reduced values below
	
	var bike_up: Vector3 = global_transform.basis.y
	
	# Target: bike up should align with ground_up, plus steering lean
	var lean_offset: float = 0.0
	var relative_speed: float = _relative_velocity.length()
	if relative_speed > min_lean_speed:
		lean_offset = steer_input * lean_into_turn_angle
		# Scale lean with speed (more lean at higher speed)
		lean_offset *= clampf(relative_speed / 10.0, 0.5, 1.0)
	
	var target_up: Vector3 = _ground_up
	if absf(lean_offset) > 0.01 and _ground_forward.length() > 0.5:
		target_up = _ground_up.rotated(_ground_forward, lean_offset)
	
	# Orientation error as axis-angle
	var error_axis: Vector3 = bike_up.cross(target_up)
	var error_magnitude: float = error_axis.length()
	
	if error_magnitude < 0.001:
		return  # Already aligned
	
	error_axis = error_axis.normalized()
	var error_angle: float = asin(clampf(error_magnitude, -1.0, 1.0))
	
	# === MODE-BASED STRENGTH SELECTION ===
	var upright_strength: float
	var damping_strength: float
	
	match _stability_mode:
		StabilityMode.NORMAL_GROUNDED:
			# Strong stabilization - bike should never fall over on normal terrain
			upright_strength = normal_upright_strength
			damping_strength = normal_roll_damping
		StabilityMode.STEEP_SIDEWAYS:
			# Weak stabilization - allow natural falling when slow on steep sideways slopes
			upright_strength = steep_upright_strength
			damping_strength = steep_roll_damping
		StabilityMode.CRASH_WINDOW:
			# Very weak - just enough to prevent violent oscillation
			upright_strength = steep_upright_strength * 0.1
			damping_strength = steep_roll_damping * 0.5
		_:
			return  # Should not reach here
	
	# Corrective torque (proportional to error)
	var correction_magnitude: float = error_angle * upright_strength
	
	# Damping torque (counter angular velocity on this axis)
	var ang_vel_component: float = state.angular_velocity.dot(error_axis)
	var damping_magnitude: float = -ang_vel_component * damping_strength * mass
	
	var total_torque: float = correction_magnitude + damping_magnitude
	
	# CLAMP to prevent spikes on seam transitions
	total_torque = clampf(total_torque, -max_stabilization_torque, max_stabilization_torque)
	
	state.apply_torque(error_axis * total_torque)


func _apply_roll_damping(state: PhysicsDirectBodyState3D) -> void:
	## Apply dedicated roll-axis damping to prevent sideways tip accumulation.
	## This is separate from the general angular damping and stabilization.
	## Prevents small bumps from building up roll velocity that leads to falling over.
	
	# Only apply in grounded modes
	if _stability_mode == StabilityMode.AIR:
		return
	
	# Roll axis is the bike's forward direction (rotation around forward = roll)
	var roll_axis: Vector3 = global_transform.basis.z
	
	# Get roll rate (angular velocity component around roll axis)
	var roll_rate: float = state.angular_velocity.dot(roll_axis)
	
	# Select damping strength based on mode
	var damping_strength: float
	match _stability_mode:
		StabilityMode.NORMAL_GROUNDED:
			damping_strength = normal_roll_damping
		StabilityMode.STEEP_SIDEWAYS:
			damping_strength = steep_roll_damping
		StabilityMode.CRASH_WINDOW:
			damping_strength = steep_roll_damping * 0.3
		_:
			return
	
	# Apply counter-torque to damp roll rotation
	var damping_torque: Vector3 = -roll_axis * roll_rate * damping_strength * mass
	
	# Clamp to prevent extreme forces
	var max_roll_damping_torque: float = max_stabilization_torque * 0.5
	var torque_mag: float = damping_torque.length()
	if torque_mag > max_roll_damping_torque:
		damping_torque = damping_torque.normalized() * max_roll_damping_torque
	
	state.apply_torque(damping_torque)


func _apply_traction(state: PhysicsDirectBodyState3D, throttle: float, brake: float, drifting: bool) -> void:
	## Apply force-based traction in the ground frame.
	## Replaces the old velocity alignment which deleted lateral motion on slopes.
	
	if not _is_grounded:
		return  # No traction while airborne
	
	# Decompose RELATIVE velocity into ground frame
	var forward_speed: float = _relative_velocity.dot(_ground_forward)
	var lateral_speed: float = _relative_velocity.dot(_ground_right)
	
	# === Forward traction ===
	var target_speed: float = 0.0
	if throttle > 0:
		target_speed = throttle * max_speed
	elif brake > 0:
		target_speed = -brake * max_speed * 0.3  # Reverse is slower
	
	var speed_error: float = target_speed - forward_speed
	
	# Desired acceleration, then convert to force: F = m * a
	var desired_accel: float = speed_error / traction_accel_time
	var traction_force: float = desired_accel * mass
	
	# Clamp to engine/brake limits (Newtons)
	if speed_error > 0:
		traction_force = clampf(traction_force, 0.0, engine_force)
	else:
		traction_force = clampf(traction_force, -brake_force, 0.0)
	
	# Additional safety clamp for seam transitions
	traction_force = clampf(traction_force, -max_traction_force, max_traction_force)
	
	state.apply_central_force(_ground_forward * traction_force)
	
	# === Lateral damping ===
	# This provides precision without deleting sideways motion on slopes
	var grip: float = drift_lateral_grip if drifting else lateral_grip_strength
	var lateral_force: float = -lateral_speed * grip * mass
	
	# Clamp to prevent spike on sudden normal changes
	lateral_force = clampf(lateral_force, -max_traction_force, max_traction_force)
	
	state.apply_central_force(_ground_right * lateral_force)


func _apply_suspension(delta: float) -> void:
	# Store previous compression for velocity calculation
	_prev_front_compression = _front_suspension_compression
	_prev_rear_compression = _rear_suspension_compression
	
	# Front wheel suspension
	if _front_grounded:
		var probe_origin: Vector3 = _front_wheel_probe.global_position
		var probe_hit: Vector3 = _front_contact_point
		var current_length: float = probe_origin.distance_to(probe_hit)
		
		# Calculate compression (positive = compressed, negative = extended)
		_front_suspension_compression = suspension_rest_length - current_length
		_front_suspension_compression = clamp(_front_suspension_compression, -max_suspension_travel, max_suspension_travel)
		
		# Calculate compression velocity for damping
		var compression_velocity: float = (_front_suspension_compression - _prev_front_compression) / delta
		
		# Spring force: F = stiffness * compression - damping * velocity
		var spring_force: float = suspension_stiffness * _front_suspension_compression
		var damping_force: float = suspension_damping * compression_velocity
		var total_force: float = spring_force - damping_force
		
		# Apply force at wheel contact point, along the ground normal
		if total_force > 0:
			var force_vec: Vector3 = _front_normal * total_force
			var force_pos: Vector3 = _front_contact_point - global_position
			apply_force(force_vec, force_pos)
		
		# Visual offset for wheel (moves down when compressed)
		_front_wheel_visual_offset = -_front_suspension_compression
	else:
		# No ground contact - extend suspension to rest
		_front_suspension_compression = lerp(_front_suspension_compression, 0.0, 5.0 * delta)
		_front_wheel_visual_offset = lerp(_front_wheel_visual_offset, 0.0, 5.0 * delta)
	
	# Rear wheel suspension
	if _rear_grounded:
		var probe_origin: Vector3 = _rear_wheel_probe.global_position
		var probe_hit: Vector3 = _rear_contact_point
		var current_length: float = probe_origin.distance_to(probe_hit)
		
		_rear_suspension_compression = suspension_rest_length - current_length
		_rear_suspension_compression = clamp(_rear_suspension_compression, -max_suspension_travel, max_suspension_travel)
		
		var compression_velocity: float = (_rear_suspension_compression - _prev_rear_compression) / delta
		
		var spring_force: float = suspension_stiffness * _rear_suspension_compression
		var damping_force: float = suspension_damping * compression_velocity
		var total_force: float = spring_force - damping_force
		
		if total_force > 0:
			var force_vec: Vector3 = _rear_normal * total_force
			var force_pos: Vector3 = _rear_contact_point - global_position
			apply_force(force_vec, force_pos)
		
		_rear_wheel_visual_offset = -_rear_suspension_compression
	else:
		_rear_suspension_compression = lerp(_rear_suspension_compression, 0.0, 5.0 * delta)
		_rear_wheel_visual_offset = lerp(_rear_wheel_visual_offset, 0.0, 5.0 * delta)


func _update_center_of_mass(delta: float) -> void:
	## Dynamically adjust center of mass based on grounded state.
	## Lower COM when grounded = much harder to tip over (huge stability boost).
	## Normal COM when airborne = flips and tricks feel responsive.
	
	var target_y: float
	if _is_grounded:
		target_y = grounded_com_offset
	else:
		target_y = 0.0  # Normal COM when airborne
	
	# Smooth transition to avoid jarring physics changes
	var current_com: Vector3 = center_of_mass
	var new_y: float = lerpf(current_com.y, target_y, 10.0 * delta)
	center_of_mass = Vector3(current_com.x, new_y, current_com.z)


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
		# Apply suspension visual offset (wheel moves up/down relative to fork)
		_front_wheel.position.y = 0.35 + _front_wheel_visual_offset
	if _rear_wheel:
		_rear_wheel.rotation.x = _wheel_rotation
		_rear_wheel.position.y = 0.35 + _rear_wheel_visual_offset

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
	# Zero ALL physics state
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Set position and rotation
	global_position = pos
	global_rotation = Vector3.ZERO
	global_transform.basis = Basis.IDENTITY
	
	# Reset internal state
	_wheel_rotation = 0.0
	_steering_angle = 0.0
	_visual_lean = 0.0
	_rear_lean = 0.0
	_landing_squash = 0.0
	_was_airborne = false
	
	# Reset suspension
	_front_suspension_compression = 0.0
	_rear_suspension_compression = 0.0
	_front_wheel_visual_offset = 0.0
	_rear_wheel_visual_offset = 0.0
	_prev_front_compression = 0.0
	_prev_rear_compression = 0.0
	
	# Reset visuals
	if _bike_model:
		_bike_model.rotation = Vector3.ZERO
		_bike_model.scale = Vector3.ONE
	if _front_assembly:
		_front_assembly.rotation = Vector3.ZERO
	if _front_wheel:
		_front_wheel.rotation = Vector3.ZERO
		_front_wheel.position.y = 0.35
	if _rear_wheel:
		_rear_wheel.rotation = Vector3.ZERO
		_rear_wheel.position.y = 0.35


func reset_in_place() -> void:
	# Keep X and Z position, lift slightly off ground
	var new_pos: Vector3 = Vector3(global_position.x, global_position.y + 1.0, global_position.z)
	reset_position(new_pos)
	# Reset camera to face bike's forward direction
	_camera_yaw = 0.0
	if _camera_pivot:
		_camera_pivot.rotation.y = _camera_yaw
