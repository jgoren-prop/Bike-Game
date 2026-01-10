extends RigidBody3D
class_name SeesawPlatform

## A physics-based seesaw/tipping platform
## Player weight causes it to tip, slowly resets when player leaves

@export var max_tilt_angle: float = 25.0  # Degrees, max rotation in each direction
@export var reset_speed: float = 0.5  # How fast it returns to level when empty
@export var tilt_resistance: float = 2.0  # Angular damping to prevent wild spinning

var _player_on_platform: bool = false
var _player_contact_timer: float = 0.0

@onready var _initial_basis: Basis = Basis.IDENTITY


func _ready() -> void:
	# Store initial orientation
	_initial_basis = global_transform.basis
	
	# Configure physics for seesaw behavior
	gravity_scale = 0.0  # Don't fall, just rotate
	lock_rotation = false
	
	# Lock translation - seesaw only rotates, doesn't move
	axis_lock_linear_x = true
	axis_lock_linear_y = true
	axis_lock_linear_z = true
	
	# Lock yaw and roll - only pitch (tipping) allowed
	axis_lock_angular_y = true
	axis_lock_angular_z = true
	
	# Set angular damping for smooth motion
	angular_damp = tilt_resistance
	
	# Enable contact monitoring to detect player
	contact_monitor = true
	max_contacts_reported = 4


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Clamp rotation to max tilt angle
	var current_rotation: Vector3 = global_rotation
	var max_rad: float = deg_to_rad(max_tilt_angle)
	
	# Clamp pitch (X rotation)
	if abs(current_rotation.x) > max_rad:
		current_rotation.x = sign(current_rotation.x) * max_rad
		# Also zero out angular velocity in that direction to prevent fighting
		var ang_vel: Vector3 = state.angular_velocity
		if sign(ang_vel.x) == sign(current_rotation.x):
			ang_vel.x = 0.0
			state.angular_velocity = ang_vel
	
	# Apply clamped rotation
	global_rotation = current_rotation
	
	# Reset toward level when player not on platform
	if not _player_on_platform:
		var target_rotation: float = 0.0
		var current_pitch: float = global_rotation.x
		
		if abs(current_pitch) > 0.01:
			# Apply restoring torque toward level
			var restore_torque: float = -current_pitch * reset_speed * mass * 10.0
			state.apply_torque(Vector3(restore_torque, 0, 0))


func _physics_process(delta: float) -> void:
	# Check if player is still on platform
	_player_on_platform = false
	
	for body in get_colliding_bodies():
		if body is BikeController:
			_player_on_platform = true
			_player_contact_timer = 0.3  # Grace period
			break
	
	# Grace period to prevent jitter when bike bounces
	if _player_contact_timer > 0:
		_player_contact_timer -= delta
		_player_on_platform = true


