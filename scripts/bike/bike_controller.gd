extends RigidBody3D
class_name BikeController

## Trials-Style Bike Controller using RigidBody3D
## Real physics-based movement with wheelies, stoppies, and full rotation

# === STABILITY MODE STATE MACHINE ===
enum StabilityMode { AIR, NORMAL_GROUNDED, STEEP_SIDEWAYS, CRASH_WINDOW }

# === PHYSICS PARAMETERS ===
# Movement
@export var engine_force: float = 2300.0     # Forward thrust (Newtons)
@export var brake_force: float = 1000.0      # Braking force (snappy stops)
@export var max_speed: float = 15.0          # Engine-limited speed on flat ground (m/s)
@export var downhill_speed_bonus: float = 1.5 # Multiplier for max speed when going downhill (gravity assist)

# Momentum
@export var bike_mass: float = 95.0          # Mass (kg)
@export var bike_drag: float = 0.10          # Linear damping - lower for smoother landings

# Steering
@export var steer_torque: float = 250.0      # Yaw torque for turning
@export var steer_speed_factor: float = 0.4  # Less steering at high speed

# Balance/Lean (W = throttle + tilt forward, S = brake/tilt back)
@export var lean_torque: float = 400.0       # Pitch torque from input
# NOTE: pitch_stabilization removed - now handled by ground-relative _apply_stabilization()

# Arcade Handling - SLOPE-AWARE TRACTION MODEL
@export var traction_accel_time: float = 0.05      # Seconds to reach target speed when throttling
@export var lateral_grip_strength: float = 28.0    # Lateral damping multiplier (normal mode)
@export var drift_lateral_grip: float = 0.5        # Lower grip during drift
@export var max_traction_force: float = 3000.0     # Safety clamp for seam transitions
@export var drift_kickout: float = 0.0       # Lateral impulse when starting drift
@export var drift_steer_boost: float = 1.3   # Steering multiplier during drift
@export var max_lean_angle: float = 0.6      # ~35 degrees max lean (radians)

# Slope-Aware Traction (true free-roll system)
@export var idle_brake_time: float = 5.00          # Seconds to come to stop on FLAT ground only
# NOTE: downhill_roll_factor and uphill_grip_strength REMOVED - true free-roll handles slopes naturally

# Torque-Based Stabilization (see Per-Mode Stabilization Strengths for main params)
@export var lean_into_turn_angle: float = 0.06       # Radians (~3.4 degrees) - how much bike leans into turns
@export var max_stabilization_torque: float = 800.0  # Hard clamp for safety
@export var min_lean_speed: float = 2.0              # No lean below this speed

# Ground Probing
@export var normal_smoothing_base: int = 5   # Frames at low speed (~42ms at 120Hz)
@export var normal_smoothing_min: int = 2   # Frames at high speed (~17ms)

# Legacy Systems (behind toggles for testing)
@export var enable_legacy_bump_assist: bool = false
@export var enable_legacy_climb_assist: bool = false

# Jump
@export var jump_impulse: float = 650.0      # Impulse when jumping (perpendicular to bike bottom)

# Arcade Feel Parameters
@export var angular_damping_value: float = 0.8  # Angular damping (rotation resistance)
@export var air_pitch_torque: float = 450.0   # Air flip responsiveness
@export var air_yaw_torque: float = 180.0      # Air spin responsiveness
@export var fov_boost: float = 1.0            # Max FOV increase at top speed
@export var landing_squash_amount: float = 0.10  # Visual squash on landing
@export var disable_visual_effects: bool = false  # Debug: disable visual lean/squash

# Camera Parameters
@export var base_fov: float = 65.0            # Base field of view
@export var camera_distance: float = 5.5      # Distance behind bike
@export var camera_height: float = 3.0        # Height above bike
@export var camera_angle: float = 16.0        # Pitch angle (degrees) - how much camera looks down
@export var camera_auto_follow_speed_threshold: float = 10.0  # Min speed for camera to auto-return after mouse look

# Suspension Parameters
# IMPORTANT: Max spring force = stiffness * max_travel * 2 wheels must exceed bike weight (mass * 9.8)
# For 95kg bike: needs > 931N. With stiffness=5000, travel=0.15: 5000*0.15*2 = 1500N ✓
@export var suspension_stiffness: float = 2500.0  # Spring force (N/m) - must support bike weight!
@export var suspension_damping: float = 50.0      # Damper - higher for critical damping (reduces oscillation)
@export var suspension_rest_length: float = 0.40  # Neutral suspension position (matches actual probe-to-ground distance)
@export var max_suspension_travel: float = 0.15   # Max compression/extension - enough headroom for weight

# Tire Grip Parameters
@export var tire_grip: float = 5.00               # How well tires climb obstacles (0 = no grip, 5+ = very sticky)
@export var front_climb_force: float = 1200.0     # Force to help front wheel climb bumps (needs to exceed bike weight)
@export var bump_pop_strength: float = 0.3        # How strong the "pop" assist is when stuck on bumps (0-1)


# Tipping System (angle-based for intuitive tuning)
@export_group("Tipping Behavior")
@export_range(10.0, 60.0, 1.0) var tip_start_angle: float = 42.0      # Slope angle where tipping becomes possible
@export_range(15.0, 90.0, 1.0) var tip_full_angle: float = 75.0       # Slope angle where tipping is fully enabled
@export_range(0.1, 0.9, 0.05) var roll_risk_threshold: float = 0.75   # How much bike_right must point downhill (0-1, lower = easier to tip)
@export_range(1.0, 15.0, 0.5) var tip_safe_speed: float = 3.5         # Speed above which tipping is fully prevented
@export_range(50.0, 400.0, 10.0) var tip_torque_strength: float = 200.0  # Torque applied to accelerate tip-over (Nm)
@export var crash_impact_threshold: float = 15.0    # Impulse magnitude to trigger crash window
@export var crash_window_duration: float = 0.5      # Seconds of reduced stabilization after impact

# Per-Mode Stabilization Strengths
@export var normal_upright_strength: float = 575.0  # Strong for normal driving (never fall)
@export var normal_roll_damping: float = 210.0      # Moderate damping for smooth stabilization (direct Nm/(rad/s))
@export var steep_upright_strength: float = 10.0    # Low when tipping - allow bike to fall with slight resistance
@export var steep_roll_damping: float = 1.0         # Minimal damping so physics can roll freely

# COM Shifting (lowers center of mass when grounded for stability)
@export var grounded_com_offset: float = -0.05      # Less COM lowering = less artificial stability
@export var grounded_com_forward: float = 0.15      # Shift COM forward to counteract drive torque pitching

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
var _roll_risk: float = 0.0                 # How much gravity wants to roll bike over (0-1)
var _tip_blend: float = 0.0                 # Slope-based blend for stabilization (0 = stable, 1 = full tip)
var _speed_blend_for_tip: float = 0.0       # Speed-based blend for tip assist only

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
@onready var _front_dust_particles: GPUParticles3D = $FrontDustParticles
@onready var _rear_dust_particles: GPUParticles3D = $RearDustParticles

signal speed_changed(speed: float)
signal flip_completed(flip_type: String, rotation_count: int)

var _bump_assist_active: bool = false  # Track if we're currently assisting a bump climb

# === FLIP TRACKING ===
# Tracks rotation through inverted states to count flips
var _is_currently_inverted: bool = false   # Is bike upside down right now?
var _inversion_count: int = 0              # How many times we entered inverted state
var _flip_direction: int = 0               # +1 = frontflip, -1 = backflip
var _peak_inversion: float = 1.0           # Most inverted we got (lowest dot product)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	## Physics-critical operations that must run during physics step.
	## NOTE: Some forces (drive, brake, steering) remain in _physics_process because:
	##   1. Drive force is applied at wheel contact points for realistic wheelie torque
	##   2. Contact points come from _check_ground() which runs in _physics_process
	##   3. This split is intentional for trials-style bike dynamics
	
	# Compute ground frame FIRST - all other physics uses this
	_compute_ground_frame(state)
	
	# Update stability state machine (determines stabilization behavior)
	_update_stability_mode(state)
	
	# === PLATFORM VELOCITY TRACKING ===
	# When on a moving platform, apply force to match platform's vertical velocity
	# This prevents bouncing on accelerating platforms (suspension alone can't track acceleration)
	_apply_platform_coupling(state)
	
	# Get input for physics
	var throttle: float = 1.0 if Input.is_action_pressed("accelerate") else 0.0
	var brake: float = 1.0 if Input.is_action_pressed("brake") else 0.0
	var steer: float = Input.get_axis("steer_right", "steer_left")
	var drifting: bool = Input.is_physical_key_pressed(KEY_SHIFT)
	
	# === SUSPENSION (moved here for proper physics sync) ===
	_apply_suspension_physics(state)
	
	# === NEW TRACTION MODEL (Phase 3) ===
	# Force-based traction in ground frame - fixes slope traversal
	_apply_traction(state, throttle, brake, drifting)
	
	# === TORQUE-BASED STABILIZATION (Phase 4) ===
	# Replaces direct global_rotation writes - works WITH the physics solver
	_apply_stabilization(state, steer)
	
	# === ROLL DAMPING ===
	# Prevents roll velocity accumulation from small bumps
	_apply_roll_damping(state)
	
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
	# Add to group for easy discovery by UI
	add_to_group("bike")
	
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
	# Compute surface velocity ONCE per frame before anything uses it
	# This must happen before _apply_suspension and before _integrate_forces
	_surface_velocity = _compute_surface_velocity()
	
	# NOTE: Suspension moved to _integrate_forces for proper physics sync
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
	# Force direction is ALWAYS projected onto ground plane (tire pushes tangent to surface)
	if throttle > 0 and _rear_grounded:
		var current_speed: float = linear_velocity.length()
		var speed_ratio: float = clamp(current_speed / max_speed, 0.0, 1.0)
		var accel_curve: float = 1.0 - (speed_ratio * speed_ratio * 0.6)  # Quadratic falloff

		# Project bike forward onto the ground plane - tire force is tangent to ground
		# This is physically correct: wheels push along the surface, not in bike direction
		var ground_forward: Vector3 = (forward - _rear_normal * forward.dot(_rear_normal))
		if ground_forward.length() > 0.1:
			ground_forward = ground_forward.normalized()
		else:
			# Bike is nearly perpendicular to ground (extreme wheelie) - use horizontal projection
			ground_forward = Vector3(forward.x, 0, forward.z).normalized()
		
		var force_vec: Vector3 = ground_forward * throttle * engine_force * accel_curve
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
			# Reduce lean torque at high speed - acceleration already creates forward pitch
			# This prevents the rear wheel from lifting when going fast with W held
			var lean_speed_factor: float = 1.0 - clampf(current_speed / 15.0, 0.0, 0.7)  # 70% reduction at 15+ m/s
			var lean_torque_applied: Vector3 = horizontal_right * tilt * lean_torque * lean_speed_factor
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

	# NOTE: Legacy pitch_stabilization REMOVED - was using world-relative global_rotation.x
	# which conflicted with the ground-relative _apply_stabilization() system.
	# All stabilization is now handled by _apply_stabilization() in _integrate_forces().

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
		
		# === FLIP COMPLETION CHECK ===
		# Count flips based on how many times we went inverted
		# Landing upright after going inverted = completed those flips
		var landing_upright: bool = global_transform.basis.y.dot(Vector3.UP) > 0.1
		
		# Debug output
		print("[FLIP DEBUG] inversions=%d, landing_upright=%s, peak=%.2f, currently_inverted=%s" % [
			_inversion_count, landing_upright, _peak_inversion, _is_currently_inverted
		])
		
		if _inversion_count > 0 and landing_upright:
			var flip_name: String = "FRONTFLIP" if _flip_direction > 0 else "BACKFLIP"
			print("[FLIP] Landed with %d %s!" % [_inversion_count, flip_name])
			flip_completed.emit(flip_name, _inversion_count)
		
		# Reset flip tracking on landing
		_inversion_count = 0
		_flip_direction = 0
		_is_currently_inverted = false
		_peak_inversion = 1.0
	
	# Track airborne flip rotation
	if not wheels_touching:
		if _was_airborne:
			# Continuing in air - track flip state
			_track_flip_rotation(delta)
		else:
			# Just became airborne - initialize tracking
			_inversion_count = 0
			_flip_direction = 0
			_peak_inversion = 1.0
			# Check if we're ALREADY inverted at launch (e.g., half-pipe facing up)
			var up_dot: float = global_transform.basis.y.dot(Vector3.UP)
			_is_currently_inverted = up_dot < -0.2
			# If starting inverted, count it!
			if _is_currently_inverted:
				_inversion_count = 1
				var pitch_rate: float = angular_velocity.dot(global_transform.basis.x)
				_flip_direction = 1 if pitch_rate > 0 else -1
	
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
	
	# === DUST PARTICLE EFFECTS ===
	_update_dust_particles(speed)


func _check_ground() -> void:
	# Calculate speed-adaptive smoothing window
	var current_speed: float = linear_velocity.length()
	var speed_ratio: float = clampf(current_speed / max_speed, 0.0, 1.0)
	var smoothing_frames: int = int(lerpf(float(normal_smoothing_base), float(normal_smoothing_min), speed_ratio))
	
	# Front wheel probe (ShapeCast3D)
	var was_front_grounded: bool = _front_grounded
	_front_grounded = _front_wheel_probe.is_colliding()
	if _front_grounded:
		# Select best hit from multiple collisions (reduces jitter on faceted surfaces)
		var best_hit: Dictionary = _select_best_hit(_front_wheel_probe, _smoothed_front_normal)
		_front_contact_point = best_hit.point
		_front_normal = best_hit.normal
		
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
		# Select best hit from multiple collisions (reduces jitter on faceted surfaces)
		var best_hit: Dictionary = _select_best_hit(_rear_wheel_probe, _smoothed_rear_normal)
		_rear_contact_point = best_hit.point
		_rear_normal = best_hit.normal
		
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


func _select_best_hit(probe: ShapeCast3D, prev_normal: Vector3) -> Dictionary:
	## Select the best hit from multiple ShapeCast collisions.
	## Uses a combination of:
	## - Closest hit along cast direction (primary)
	## - Highest alignment with previous normal (temporal stability tiebreaker)
	## Returns: { point: Vector3, normal: Vector3 }
	
	var hit_count: int = probe.get_collision_count()
	if hit_count == 0:
		return { "point": Vector3.ZERO, "normal": Vector3.UP }
	
	if hit_count == 1:
		return { "point": probe.get_collision_point(0), "normal": probe.get_collision_normal(0) }
	
	# Cast direction (probe target is local, convert to world)
	var cast_dir: Vector3 = probe.global_transform.basis * probe.target_position.normalized()
	var probe_origin: Vector3 = probe.global_position
	
	var best_idx: int = 0
	var best_score: float = -INF
	
	for i in hit_count:
		var point: Vector3 = probe.get_collision_point(i)
		var normal: Vector3 = probe.get_collision_normal(i)
		
		# Distance along cast direction (closer = better, so we want smaller values)
		# Convert to score by negating (closer = higher score)
		var to_point: Vector3 = point - probe_origin
		var distance_along_cast: float = to_point.dot(cast_dir)
		
		# Temporal stability: favor normals similar to previous frame
		var normal_alignment: float = normal.dot(prev_normal)
		
		# Combined score: primarily distance (closer is better), with normal alignment as tiebreaker
		# Distance is negative score (closer = smaller distance = less negative = higher)
		# Multiply alignment by small factor so it only matters for ties
		var score: float = -distance_along_cast + normal_alignment * 0.1
		
		if score > best_score:
			best_score = score
			best_idx = i
	
	return { "point": probe.get_collision_point(best_idx), "normal": probe.get_collision_normal(best_idx) }


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
	
	# Use cached surface velocity (computed in _physics_process before this runs)
	# NOTE: _surface_velocity is already set, just compute relative velocity
	_relative_velocity = state.linear_velocity - _surface_velocity
	
	# Blend normals: weight by suspension compression when both grounded
	# More compression = firmer contact = more influence on ground normal
	# This reduces "rocking" on curved surfaces like half-pipes
	var blended_normal: Vector3
	if _front_grounded and _rear_grounded:
		# Base weights (rear-biased for stability)
		var front_base_weight: float = 0.3
		var rear_base_weight: float = 0.7
		
		# Adjust weights by compression (more compressed = more influence)
		# Use smoothed compression to avoid jitter
		var front_compression_factor: float = clampf(_front_suspension_compression / max_suspension_travel, 0.0, 1.0)
		var rear_compression_factor: float = clampf(_rear_suspension_compression / max_suspension_travel, 0.0, 1.0)
		
		# Blend factor based on relative compression
		# If rear is more compressed, increase rear weight; if front is more compressed, increase front weight
		var compression_diff: float = rear_compression_factor - front_compression_factor
		# Shift weights by up to 0.2 based on compression difference
		var weight_shift: float = compression_diff * 0.2
		
		var front_weight: float = clampf(front_base_weight - weight_shift, 0.1, 0.5)
		var rear_weight: float = clampf(rear_base_weight + weight_shift, 0.5, 0.9)
		
		# Normalize weights
		var total_weight: float = front_weight + rear_weight
		front_weight /= total_weight
		rear_weight /= total_weight
		
		blended_normal = (_smoothed_rear_normal * rear_weight + _smoothed_front_normal * front_weight).normalized()
	elif _rear_grounded:
		blended_normal = _smoothed_rear_normal
	else:
		blended_normal = _smoothed_front_normal
	
	# Rate-limited slerp to prevent sudden ground_up jumps on faceted surfaces
	# Max angular change per frame: ~15 degrees at 120Hz = 1800 deg/sec
	# This smooths out triangle boundary transitions without adding lag on smooth surfaces
	var max_angle_per_frame: float = deg_to_rad(15.0)
	var angle_to_new: float = _ground_up.angle_to(blended_normal)
	
	if angle_to_new > max_angle_per_frame:
		# Limit angular change rate
		var t: float = max_angle_per_frame / angle_to_new
		_ground_up = _ground_up.slerp(blended_normal, t)
	else:
		# Small change, apply directly
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


func _compute_surface_velocity() -> Vector3:
	## Compute velocity of the surface we're standing on (for moving platforms).
	## Returns Vector3.ZERO for static surfaces.
	## NOTE: Call this ONCE per frame and cache the result in _surface_velocity.
	
	if not _front_grounded and not _rear_grounded:
		return Vector3.ZERO
	
	# Get the collider from probe (prefer rear)
	var probe: ShapeCast3D = _rear_wheel_probe if _rear_grounded else _front_wheel_probe
	if probe.get_collision_count() == 0:
		return Vector3.ZERO
	
	var collider: Object = probe.get_collider(0)
	if collider == null:
		return Vector3.ZERO
	
	# Static bodies have zero velocity, BUT AnimatableBody3D inherits from StaticBody3D
	# so we must check for AnimatableBody3D first!
	if collider is AnimatableBody3D:
		pass  # Continue to compute velocity
	elif collider is StaticBody3D:
		return Vector3.ZERO  # True static body - no velocity
	
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
	
	var velocity: Vector3 = (current_pos - prev_pos) / dt
	return velocity


func _compute_roll_risk() -> float:
	## Compute how much gravity wants to roll the bike over.
	## Returns 0.0 when bike_right is across slope (stable).
	## Returns 1.0 when bike_right points straight downhill (maximum tip risk).
	
	if not _is_grounded:
		return 0.0
	
	# Downhill direction = gravity projected onto slope plane
	var gravity_slope: Vector3 = Vector3.DOWN - _ground_up * Vector3.DOWN.dot(_ground_up)
	if gravity_slope.length() < 0.001:
		return 0.0  # Flat ground - no roll risk
	
	var downhill_dir: Vector3 = gravity_slope.normalized()
	
	# Roll risk = how much bike's RIGHT axis aligns with downhill
	var bike_right: Vector3 = global_transform.basis.x
	return absf(bike_right.dot(downhill_dir))


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
		_tip_blend = 0.0
		return
	
	# === CRASH WINDOW ACTIVE ===
	if _crash_window_timer > 0:
		_stability_mode = StabilityMode.CRASH_WINDOW
		_tip_blend = 0.0
		return
	
	# === AIR CHECK ===
	if not _is_grounded:
		_stability_mode = StabilityMode.AIR
		_tip_blend = 0.0
		return
	
	# === GROUNDED: Check for STEEP_SIDEWAYS conditions ===
	# Compute actual slope angle in degrees (cleaner mental model)
	var slope_dot: float = clampf(_ground_up.y, -1.0, 1.0)
	var slope_angle: float = rad_to_deg(acos(slope_dot))  # 0° = flat, 90° = wall
	
	# Check conditions
	var is_steep: bool = slope_angle > tip_start_angle
	_roll_risk = _compute_roll_risk()
	var is_at_risk: bool = _roll_risk > roll_risk_threshold
	
	if is_steep and is_at_risk:
		_stability_mode = StabilityMode.STEEP_SIDEWAYS
		
		# Slope blend: 0 at tip_start_angle, 1 at tip_full_angle
		# THIS is what controls stabilization reduction (independent of speed)
		var slope_blend: float = inverse_lerp(tip_start_angle, tip_full_angle, slope_angle)
		slope_blend = clampf(slope_blend, 0.0, 1.0)
		
		# Speed blend: only affects tip ASSIST torque, NOT stabilization
		var speed: float = _relative_velocity.length()
		var speed_blend: float = clampf(1.0 - (speed / tip_safe_speed), 0.0, 1.0)
		
		# FIX: Use slope_blend for stabilization reduction (bike can fall at any speed on steep slope)
		# Speed only affects the EXTRA push from tip assist
		_tip_blend = slope_blend  # Changed from slope_blend * speed_blend
		_speed_blend_for_tip = speed_blend  # Store separately for tip assist
	else:
		_stability_mode = StabilityMode.NORMAL_GROUNDED
		_tip_blend = 0.0
		_speed_blend_for_tip = 0.0


func _apply_stabilization(state: PhysicsDirectBodyState3D, steer_input: float) -> void:
	## Apply torque-based upright stabilization based on current stability mode.
	## Uses mode-specific strength: strong for normal driving, blended when on steep slopes.
	## In STEEP_SIDEWAYS mode, also applies tip-over assist torque.
	
	# === MODE-BASED EARLY EXIT ===
	# AIR: No stabilization - player has full control for tricks
	if _stability_mode == StabilityMode.AIR:
		return
	
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
		# Already aligned - but still apply tip-over assist if needed
		_apply_tip_over_assist(state)
		return
	
	error_axis = error_axis.normalized()
	var error_angle: float = asin(clampf(error_magnitude, -1.0, 1.0))
	
	# === MODE-BASED STRENGTH SELECTION (with blending) ===
	var upright_strength: float
	var damping_strength: float
	
	match _stability_mode:
		StabilityMode.NORMAL_GROUNDED:
			# Strong stabilization - bike should never fall over on normal terrain
			upright_strength = normal_upright_strength
			damping_strength = normal_roll_damping
		StabilityMode.STEEP_SIDEWAYS:
			# Blend from normal to steep based on _tip_blend
			upright_strength = lerpf(normal_upright_strength, steep_upright_strength, _tip_blend)
			damping_strength = lerpf(normal_roll_damping, steep_roll_damping, _tip_blend)
		StabilityMode.CRASH_WINDOW:
			# Very weak - just enough to prevent violent oscillation
			upright_strength = steep_upright_strength * 0.1
			damping_strength = steep_roll_damping * 0.5
		_:
			return  # Should not reach here
	
	# Corrective torque (proportional to error)
	var correction_magnitude: float = error_angle * upright_strength
	
	# Damping torque (counter angular velocity on this axis)
	# NOTE: Removed mass multiplier - damping_strength is now direct Nm/(rad/s)
	var ang_vel_component: float = state.angular_velocity.dot(error_axis)
	var damping_magnitude: float = -ang_vel_component * damping_strength
	
	var total_torque: float = correction_magnitude + damping_magnitude
	
	# CLAMP to prevent spikes on seam transitions
	total_torque = clampf(total_torque, -max_stabilization_torque, max_stabilization_torque)
	
	state.apply_torque(error_axis * total_torque)
	
	# === TIP-OVER ASSIST ===
	_apply_tip_over_assist(state)


func _apply_tip_over_assist(state: PhysicsDirectBodyState3D) -> void:
	## Apply destabilizing torque to accelerate tipping when on steep sideways slopes.
	## Uses roll-risk direction to determine which way to tip.
	
	if _stability_mode != StabilityMode.STEEP_SIDEWAYS or _tip_blend < 0.05:
		return
	
	var gravity_slope: Vector3 = Vector3.DOWN - _ground_up * Vector3.DOWN.dot(_ground_up)
	if gravity_slope.length() < 0.001:
		return
	
	var downhill_dir: Vector3 = gravity_slope.normalized()
	
	var bike_right: Vector3 = global_transform.basis.x
	var roll_axis: Vector3 = global_transform.basis.z  # Roll axis (+Z forward)
	
	# +1 = downhill is to bike's right, -1 = downhill is to bike's left
	var downhill_side: float = signf(bike_right.dot(downhill_dir))
	
	# Tip strength ramps from 0 at threshold to 1 at full risk
	var risk_factor: float = clampf((_roll_risk - roll_risk_threshold) / (1.0 - roll_risk_threshold), 0.0, 1.0)
	# Use speed blend for tip ASSIST only (not stabilization)
	var tip_amt: float = _tip_blend * risk_factor * _speed_blend_for_tip
	
	var tip_torque: float = tip_amt * tip_torque_strength
	
	# NOTE: Sign may need flipping - test in-game and change to +downhill_side if wrong
	var actual_tip_torque: Vector3 = roll_axis * -downhill_side * tip_torque
	state.apply_torque(actual_tip_torque)


func _apply_roll_damping(state: PhysicsDirectBodyState3D) -> void:
	## Apply dedicated roll-axis damping to prevent sideways tip accumulation.
	## This is separate from the general angular damping and stabilization.
	## Prevents small bumps from building up roll velocity that leads to falling over.
	## CRITICAL: Uses _tip_blend to reduce damping when tipping should be allowed.
	
	# Only apply in grounded modes
	if _stability_mode == StabilityMode.AIR:
		return
	
	# Roll axis is the bike's forward direction (rotation around forward = roll)
	var roll_axis: Vector3 = global_transform.basis.z
	
	# Get roll rate (angular velocity component around roll axis)
	var roll_rate: float = state.angular_velocity.dot(roll_axis)
	
	# Select damping strength based on mode (with blending for STEEP_SIDEWAYS)
	var damping_strength: float
	match _stability_mode:
		StabilityMode.NORMAL_GROUNDED:
			damping_strength = normal_roll_damping
		StabilityMode.STEEP_SIDEWAYS:
			# Blend down aggressively so we don't fight the fall
			damping_strength = lerpf(normal_roll_damping, steep_roll_damping, _tip_blend)
		StabilityMode.CRASH_WINDOW:
			damping_strength = steep_roll_damping * 0.3
		_:
			return
	
	# Apply counter-torque to damp roll rotation
	# NOTE: Removed mass multiplier - damping_strength is now direct Nm/(rad/s)
	var damping_torque: Vector3 = -roll_axis * roll_rate * damping_strength
	
	# Clamp to prevent extreme forces
	var max_roll_damping_torque: float = max_stabilization_torque * 0.5
	var torque_mag: float = damping_torque.length()
	if torque_mag > max_roll_damping_torque:
		damping_torque = damping_torque.normalized() * max_roll_damping_torque
	
	state.apply_torque(damping_torque)


func _apply_traction(state: PhysicsDirectBodyState3D, throttle: float, brake: float, drifting: bool) -> void:
	## Apply slope-aware traction in the ground frame.
	## NOTE: Forward acceleration is handled by engine_force in _physics_process (applied at wheel).
	## This function only handles:
	## - Lateral grip (prevents sliding sideways)
	## - Idle braking on flat ground (gentle stop when no input)
	## Forward propulsion via engine_force creates natural wheelie/stoppie physics.
	
	if not _is_grounded:
		return  # No traction while airborne
	
	# Decompose RELATIVE velocity into ground frame
	var forward_speed: float = _relative_velocity.dot(_ground_forward)
	var lateral_speed: float = _relative_velocity.dot(_ground_right)
	
	# === IDLE BRAKING (flat ground only, no throttle/brake) ===
	# Gently slow the bike to a stop when no input on flat ground
	# On slopes, let gravity handle it (true free-roll)
	if throttle == 0 and brake == 0:
		var slope_factor: float = _ground_forward.dot(Vector3.DOWN)
		var abs_slope: float = absf(slope_factor)
		
		if abs_slope < 0.03:  # Nearly flat ground
			# Gentle braking force to stop
			var target_speed: float = 0.0
			var speed_error: float = target_speed - forward_speed
			var desired_accel: float = speed_error / idle_brake_time
			var brake_force_applied: float = desired_accel * mass
			brake_force_applied = clampf(brake_force_applied, -brake_force * 0.3, brake_force * 0.3)
			state.apply_central_force(_ground_forward * brake_force_applied)
	
	# === Lateral damping ===
	# This provides precision steering without deleting sideways motion on slopes
	# Always active to prevent uncontrolled sliding
	var grip: float = drift_lateral_grip if drifting else lateral_grip_strength
	var lateral_force: float = -lateral_speed * grip * mass
	
	# Clamp to prevent spike on sudden normal changes
	lateral_force = clampf(lateral_force, -max_traction_force, max_traction_force)
	
	state.apply_central_force(_ground_right * lateral_force)


func _apply_platform_coupling(_state: PhysicsDirectBodyState3D) -> void:
	## Platform coupling disabled - using high suspension damping instead.
	## The suspension system with proper damping handles moving platforms naturally.
	pass


func _apply_suspension_physics(state: PhysicsDirectBodyState3D) -> void:
	## Apply suspension forces within _integrate_forces for proper physics sync.
	## Using state.apply_force ensures forces are applied at the correct physics step.
	
	var delta: float = state.step
	
	# Store previous compression for velocity calculation
	_prev_front_compression = _front_suspension_compression
	_prev_rear_compression = _rear_suspension_compression
	
	# Front wheel suspension
	if _front_grounded:
		var probe_origin: Vector3 = _front_wheel_probe.global_position
		var probe_hit: Vector3 = _front_contact_point
		
		# Measure length along probe's cast axis (not Euclidean distance)
		# This prevents jitter when hit point walks across triangle boundaries
		var probe_down: Vector3 = (_front_wheel_probe.global_transform.basis * _front_wheel_probe.target_position).normalized()
		var to_hit: Vector3 = probe_hit - probe_origin
		var current_length: float = to_hit.dot(probe_down)
		
		# Calculate raw compression and smooth it to reduce jitter on curved surfaces
		var raw_compression: float = suspension_rest_length - current_length
		raw_compression = clamp(raw_compression, -max_suspension_travel, max_suspension_travel)
		_front_suspension_compression = lerpf(_front_suspension_compression, raw_compression, 15.0 * delta)
		
		var compression_velocity: float = (_front_suspension_compression - _prev_front_compression) / delta
		
		var spring_force: float = suspension_stiffness * _front_suspension_compression
		var damping_force: float = suspension_damping * compression_velocity
		var total_force: float = spring_force + damping_force
		
		var force_multiplier: float = 1.0 if _stability_mode != StabilityMode.STEEP_SIDEWAYS else (1.0 - _tip_blend)
		if total_force > 0:
			var force_vec: Vector3 = _front_normal * total_force * force_multiplier
			var force_pos: Vector3 = _front_contact_point - global_position
			state.apply_force(force_vec, force_pos)
		
		_front_wheel_visual_offset = -_front_suspension_compression
	else:
		_front_suspension_compression = lerpf(_front_suspension_compression, 0.0, 5.0 * delta)
		_front_wheel_visual_offset = lerpf(_front_wheel_visual_offset, 0.0, 5.0 * delta)
	
	# Rear wheel suspension
	if _rear_grounded:
		var probe_origin: Vector3 = _rear_wheel_probe.global_position
		var probe_hit: Vector3 = _rear_contact_point
		
		# Measure length along probe's cast axis (not Euclidean distance)
		# This prevents jitter when hit point walks across triangle boundaries
		var probe_down: Vector3 = (_rear_wheel_probe.global_transform.basis * _rear_wheel_probe.target_position).normalized()
		var to_hit: Vector3 = probe_hit - probe_origin
		var current_length: float = to_hit.dot(probe_down)
		
		# Calculate raw compression and smooth it to reduce jitter on curved surfaces
		var raw_compression: float = suspension_rest_length - current_length
		raw_compression = clamp(raw_compression, -max_suspension_travel, max_suspension_travel)
		_rear_suspension_compression = lerpf(_rear_suspension_compression, raw_compression, 15.0 * delta)
		
		var compression_velocity: float = (_rear_suspension_compression - _prev_rear_compression) / delta
		
		var spring_force: float = suspension_stiffness * _rear_suspension_compression
		var damping_force: float = suspension_damping * compression_velocity
		var total_force: float = spring_force + damping_force
		
		var force_multiplier: float = 1.0 if _stability_mode != StabilityMode.STEEP_SIDEWAYS else (1.0 - _tip_blend)
		if total_force > 0:
			var force_vec: Vector3 = _rear_normal * total_force * force_multiplier
			var force_pos: Vector3 = _rear_contact_point - global_position
			state.apply_force(force_vec, force_pos)
		
		_rear_wheel_visual_offset = -_rear_suspension_compression
	else:
		_rear_suspension_compression = lerpf(_rear_suspension_compression, 0.0, 5.0 * delta)
		_rear_wheel_visual_offset = lerpf(_rear_wheel_visual_offset, 0.0, 5.0 * delta)


func _apply_suspension(delta: float) -> void:
	# Store previous compression for velocity calculation
	_prev_front_compression = _front_suspension_compression
	_prev_rear_compression = _rear_suspension_compression
	
	# Use cached platform velocity (computed at start of _physics_process)
	var platform_vertical_vel: float = _surface_velocity.y
	
	# Front wheel suspension
	if _front_grounded:
		var probe_origin: Vector3 = _front_wheel_probe.global_position
		var probe_hit: Vector3 = _front_contact_point
		
		# Measure length along probe's cast axis (not Euclidean distance)
		# This prevents jitter when hit point walks across triangle boundaries
		var probe_down: Vector3 = (_front_wheel_probe.global_transform.basis * _front_wheel_probe.target_position).normalized()
		var to_hit: Vector3 = probe_hit - probe_origin
		var current_length: float = to_hit.dot(probe_down)
		
		# Calculate compression (positive = compressed, negative = extended)
		_front_suspension_compression = suspension_rest_length - current_length
		_front_suspension_compression = clamp(_front_suspension_compression, -max_suspension_travel, max_suspension_travel)
		
		# Compression velocity: rate of change of spring length
		# This is INHERENTLY platform-relative because we measure probe_origin (bike) to probe_hit (platform)
		# NO platform velocity adjustment needed - the measurement already accounts for both motions
		var compression_velocity: float = (_front_suspension_compression - _prev_front_compression) / delta
		
		# Spring-damper force: F = k*x + c*v
		# Spring resists displacement, damper resists velocity (both push back during compression)
		var spring_force: float = suspension_stiffness * _front_suspension_compression
		var damping_force: float = suspension_damping * compression_velocity
		var total_force: float = spring_force + damping_force
		
		# Apply force at wheel contact point, along the ground normal
		# REDUCE suspension force during STEEP_SIDEWAYS to allow tipping
		var force_multiplier: float = 1.0 if _stability_mode != StabilityMode.STEEP_SIDEWAYS else (1.0 - _tip_blend)
		if total_force > 0:
			var force_vec: Vector3 = _front_normal * total_force * force_multiplier
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
		
		# Measure length along probe's cast axis (not Euclidean distance)
		# This prevents jitter when hit point walks across triangle boundaries
		var probe_down: Vector3 = (_rear_wheel_probe.global_transform.basis * _rear_wheel_probe.target_position).normalized()
		var to_hit: Vector3 = probe_hit - probe_origin
		var current_length: float = to_hit.dot(probe_down)
		
		_rear_suspension_compression = suspension_rest_length - current_length
		_rear_suspension_compression = clamp(_rear_suspension_compression, -max_suspension_travel, max_suspension_travel)
		
		# Compression velocity: inherently platform-relative (measures actual spring length change)
		var compression_velocity: float = (_rear_suspension_compression - _prev_rear_compression) / delta
		
		var spring_force: float = suspension_stiffness * _rear_suspension_compression
		var damping_force: float = suspension_damping * compression_velocity
		var total_force: float = spring_force + damping_force
		
		# REDUCE suspension force during STEEP_SIDEWAYS to allow tipping
		var rear_force_multiplier: float = 1.0 if _stability_mode != StabilityMode.STEEP_SIDEWAYS else (1.0 - _tip_blend)
		if total_force > 0:
			var force_vec: Vector3 = _rear_normal * total_force * rear_force_multiplier
			var force_pos: Vector3 = _rear_contact_point - global_position
			apply_force(force_vec, force_pos)
		
		_rear_wheel_visual_offset = -_rear_suspension_compression
	else:
		_rear_suspension_compression = lerp(_rear_suspension_compression, 0.0, 5.0 * delta)
		_rear_wheel_visual_offset = lerp(_rear_wheel_visual_offset, 0.0, 5.0 * delta)


func _update_center_of_mass(delta: float) -> void:
	## Dynamically adjust center of mass based on grounded state.
	## Lower COM when grounded = much harder to tip over (huge stability boost).
	## Forward COM shift when grounded = counteracts acceleration pitch (prevents rear wheel lift).
	## Normal COM when airborne = flips and tricks feel responsive.
	## STEEP_SIDEWAYS: Don't lower COM - allow tipping!
	
	var target_y: float
	var target_z: float
	if not _is_grounded:
		target_y = 0.0  # Normal COM when airborne
		target_z = 0.0
	elif _stability_mode == StabilityMode.STEEP_SIDEWAYS:
		# Blend COM back to normal during tipping
		target_y = lerpf(grounded_com_offset, 0.0, _tip_blend)
		target_z = lerpf(grounded_com_forward, 0.0, _tip_blend)
	else:
		target_y = grounded_com_offset
		target_z = grounded_com_forward
	
	# Smooth transition to avoid jarring physics changes
	var current_com: Vector3 = center_of_mass
	var new_y: float = lerpf(current_com.y, target_y, 10.0 * delta)
	var new_z: float = lerpf(current_com.z, target_z, 10.0 * delta)
	center_of_mass = Vector3(current_com.x, new_y, new_z)
	
	# === REDUCE ANGULAR DAMPING DURING TIPPING ===
	# RigidBody3D's built-in angular_damp fights ALL rotation including tipping
	if _stability_mode == StabilityMode.STEEP_SIDEWAYS:
		angular_damp = lerpf(angular_damping_value, 0.0, _tip_blend)
	else:
		angular_damp = angular_damping_value


func _update_camera(delta: float) -> void:
	var speed: float = linear_velocity.length()
	
	# Handle mouse control decay with delay - only when moving fast enough
	if _mouse_hold_timer > 0:
		_mouse_hold_timer -= delta
	elif speed >= camera_auto_follow_speed_threshold:
		# Gradually reduce mouse control strength - slow fade back to auto-follow
		# Takes ~1.5 seconds to fully return to auto-follow (0.7 per second decay)
		_mouse_control_strength = maxf(0.0, _mouse_control_strength - 0.7 * delta)
	# else: speed below threshold - keep camera where user placed it
	var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)

	# === DYNAMIC FOV (speed sensation) ===
	var target_fov: float = base_fov + (speed_ratio * speed_ratio * fov_boost)
	_camera.fov = lerp(_camera.fov, target_fov, 5.0 * delta)

	# === CAMERA POSITION ===
	var height_reduction: float = 0.8  # Drop up to 0.8 units at max speed
	var target_height: float = camera_height - (speed_ratio * height_reduction)

	# Smoothly follow bike position (camera is top_level so we do this manually)
	# Faster follow when accelerating to prevent bike from getting too far ahead
	var camera_follow_speed: float = lerpf(12.0, 20.0, speed_ratio)
	var target_pos: Vector3 = global_position + Vector3(0, 1, 0)
	_camera_pivot.global_position = _camera_pivot.global_position.lerp(target_pos, camera_follow_speed * delta)

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
		if horiz_speed > 5.0:
			# Moving on ground - follow velocity direction
			# Threshold is 5.0 to prevent camera flip when just backing up for obstacles
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

	# Use relative velocity for wheel animation (accounts for moving platforms)
	# When on a moving platform, bike has world velocity but wheels shouldn't spin
	var velocity_for_wheels: Vector3 = _relative_velocity if _is_grounded else linear_velocity
	var speed: float = velocity_for_wheels.length()

	# Wheel rotation based on speed
	var wheel_circumference: float = 2.0 * PI * WHEEL_RADIUS
	var rotations_per_second: float = speed / wheel_circumference

	# Check if moving forward or backward relative to bike facing
	var forward: Vector3 = global_transform.basis.z
	var velocity_dot: float = velocity_for_wheels.dot(forward)
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


# === DUST PARTICLE EFFECTS ===

func _update_dust_particles(speed: float) -> void:
	## Control dust particle emission based on grounding and speed.
	## Dust emits when wheels are touching ground and bike is moving.
	
	if not _front_dust_particles or not _rear_dust_particles:
		return
	
	# Dust threshold - emit dust when moving faster than this (m/s)
	var dust_speed_threshold: float = 2.0
	var dust_speed_max: float = 12.0  # Full dust intensity at this speed
	
	# Calculate dust intensity based on speed
	var dust_intensity: float = clampf((speed - dust_speed_threshold) / (dust_speed_max - dust_speed_threshold), 0.0, 1.0)
	
	# Front wheel dust
	var front_should_emit: bool = _front_grounded and speed > dust_speed_threshold
	_front_dust_particles.emitting = front_should_emit
	if front_should_emit:
		# Adjust emission amount based on speed (more dust at higher speed)
		_front_dust_particles.amount_ratio = dust_intensity
	
	# Rear wheel dust - more prominent since it's the drive wheel
	var rear_should_emit: bool = _rear_grounded and speed > dust_speed_threshold
	_rear_dust_particles.emitting = rear_should_emit
	if rear_should_emit:
		_rear_dust_particles.amount_ratio = dust_intensity
	
	# Burst of dust on landing
	if _landing_squash > 0.02:
		# Landing impact - emit extra dust briefly
		_front_dust_particles.emitting = _front_grounded
		_rear_dust_particles.emitting = _rear_grounded
		if _front_grounded:
			_front_dust_particles.amount_ratio = 1.0
		if _rear_grounded:
			_rear_dust_particles.amount_ratio = 1.0


# === FLIP TRACKING ===

func _track_flip_rotation(_delta: float) -> void:
	## Track when bike passes through inverted orientation.
	## Each time we enter inverted state = potential flip.
	## Flip completes when we exit inverted or land upright.
	
	var bike_up: Vector3 = global_transform.basis.y
	var up_alignment: float = bike_up.dot(Vector3.UP)
	
	# Track peak inversion (how upside down we got)
	_peak_inversion = minf(_peak_inversion, up_alignment)
	
	# Check if we're inverted (upside down) - use threshold with hysteresis
	var now_inverted: bool
	if _is_currently_inverted:
		# Currently inverted - need to get past 0.0 to exit
		now_inverted = up_alignment < 0.0
	else:
		# Currently upright - need to get below -0.2 to enter inverted
		now_inverted = up_alignment < -0.2
	
	# Detect entering inverted state
	if now_inverted and not _is_currently_inverted:
		_inversion_count += 1
		
		# Determine flip direction from angular velocity
		if _flip_direction == 0:
			var pitch_rate: float = angular_velocity.dot(global_transform.basis.x)
			_flip_direction = 1 if pitch_rate > 0 else -1
	
	_is_currently_inverted = now_inverted


# === PUBLIC API ===

func get_current_speed() -> float:
	return linear_velocity.length()


func get_stability_mode() -> StabilityMode:
	return _stability_mode


func get_stability_mode_name() -> String:
	match _stability_mode:
		StabilityMode.AIR:
			return "AIR"
		StabilityMode.NORMAL_GROUNDED:
			return "NORMAL"
		StabilityMode.STEEP_SIDEWAYS:
			return "STEEP_SIDEWAYS"
		StabilityMode.CRASH_WINDOW:
			return "CRASH"
		_:
			return "UNKNOWN"


func get_roll_risk() -> float:
	return _roll_risk


func get_tip_blend() -> float:
	return _tip_blend


func get_slope_angle() -> float:
	## Returns the current slope angle in degrees (0 = flat, 90 = wall)
	if not _is_grounded:
		return 0.0
	var slope_dot: float = clampf(_ground_up.y, -1.0, 1.0)
	return rad_to_deg(acos(slope_dot))


func get_horizontal_speed() -> float:
	return Vector2(linear_velocity.x, linear_velocity.z).length()


func get_platform_velocity() -> Vector3:
	## Returns current platform velocity for debugging
	return _surface_velocity


func get_debug_suspension_info() -> Dictionary:
	## Returns suspension debug info for the dev panel
	return {
		"front_compression": _front_suspension_compression,
		"rear_compression": _rear_suspension_compression,
		"platform_vel_y": _surface_velocity.y,
		"on_platform": _surface_velocity.length() > 0.1
	}


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


func teleport_to(new_transform: Transform3D) -> void:
	## Teleport bike to a specific transform (position + rotation).
	## Use this for test scenes that need specific orientations.
	
	# Zero ALL physics state
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	
	# Set the full transform
	global_transform = new_transform
	
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
	
	# Reset stability mode
	_stability_mode = StabilityMode.AIR
	_tip_blend = 0.0
	_roll_risk = 0.0
	
	# Reset visuals to match new orientation
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
