extends Node3D
class_name RaccoonRider

## Raccoon rider with procedural animation for floppy limbs.
## Arms, legs, tail, and chin strap wobble based on bike motion.

# Limb references
@onready var _left_arm: Node3D = $Body/LeftArm
@onready var _right_arm: Node3D = $Body/RightArm
@onready var _left_leg: Node3D = $Body/LeftLeg
@onready var _right_leg: Node3D = $Body/RightLeg
@onready var _tail: Node3D = $Body/Tail
@onready var _tail_seg2: Node3D = $Body/Tail/Segment2
@onready var _tail_seg3: Node3D = $Body/Tail/Segment2/Segment3
@onready var _strap_loose: Node3D = $Body/Head/StrapLoose

# Base rotations (store initial transforms)
var _left_arm_base: Vector3
var _right_arm_base: Vector3
var _left_leg_base: Vector3
var _right_leg_base: Vector3
var _tail_base: Vector3
var _tail_seg2_base: Vector3
var _tail_seg3_base: Vector3
var _strap_base: Vector3

# Animation state
var _wobble_time: float = 0.0
var _prev_velocity: Vector3 = Vector3.ZERO
var _smoothed_accel: Vector3 = Vector3.ZERO


func _ready() -> void:
	# Store base rotations
	_left_arm_base = _left_arm.rotation if _left_arm else Vector3.ZERO
	_right_arm_base = _right_arm.rotation if _right_arm else Vector3.ZERO
	_left_leg_base = _left_leg.rotation if _left_leg else Vector3.ZERO
	_right_leg_base = _right_leg.rotation if _right_leg else Vector3.ZERO
	_tail_base = _tail.rotation if _tail else Vector3.ZERO
	_tail_seg2_base = _tail_seg2.rotation if _tail_seg2 else Vector3.ZERO
	_tail_seg3_base = _tail_seg3.rotation if _tail_seg3 else Vector3.ZERO
	_strap_base = _strap_loose.rotation if _strap_loose else Vector3.ZERO


func _process(delta: float) -> void:
	_wobble_time += delta
	
	# Get bike velocity from parent (assumes parent chain leads to bike RigidBody3D)
	var bike: RigidBody3D = _find_bike()
	if not bike:
		return
	
	var velocity: Vector3 = bike.linear_velocity
	var local_velocity: Vector3 = bike.global_transform.basis.inverse() * velocity
	var speed: float = velocity.length()
	
	# Calculate acceleration for reactive motion
	var accel: Vector3 = (velocity - _prev_velocity) / maxf(delta, 0.001)
	var local_accel: Vector3 = bike.global_transform.basis.inverse() * accel
	_smoothed_accel = _smoothed_accel.lerp(local_accel, 8.0 * delta)
	_prev_velocity = velocity
	
	# Wobble intensity based on speed
	var wobble_intensity: float = clampf(speed / 10.0, 0.0, 1.0)
	var accel_factor: float = clampf(_smoothed_accel.length() / 20.0, 0.0, 1.0)
	
	# === ARMS ===
	# Arms swing back when accelerating, forward when braking
	var arm_swing: float = -_smoothed_accel.z * 0.015  # Forward/back from accel
	var arm_wobble: float = sin(_wobble_time * 8.0) * 0.1 * wobble_intensity
	
	if _left_arm:
		_left_arm.rotation = _left_arm_base + Vector3(arm_swing + arm_wobble, 0, 0)
	if _right_arm:
		_right_arm.rotation = _right_arm_base + Vector3(arm_swing - arm_wobble * 0.7, 0, 0)
	
	# === LEGS ===
	# Legs dangle and swing slightly
	var leg_wobble: float = sin(_wobble_time * 6.0 + 0.5) * 0.08 * wobble_intensity
	var leg_swing: float = -_smoothed_accel.z * 0.01
	
	if _left_leg:
		_left_leg.rotation = _left_leg_base + Vector3(leg_swing + leg_wobble, 0, 0)
	if _right_leg:
		_right_leg.rotation = _right_leg_base + Vector3(leg_swing - leg_wobble * 0.8, 0, 0)
	
	# === TAIL ===
	# Tail swings side to side and reacts to turning
	var turn_rate: float = bike.angular_velocity.y
	var tail_side: float = -turn_rate * 0.3  # Swing opposite to turn
	var tail_wobble: float = sin(_wobble_time * 5.0) * 0.15 * wobble_intensity
	var tail_accel: float = _smoothed_accel.z * 0.02  # React to accel/brake
	
	if _tail:
		_tail.rotation = _tail_base + Vector3(tail_accel, 0, tail_side + tail_wobble)
	
	# Tail segments follow with delay (wave effect)
	if _tail_seg2:
		var seg2_wobble: float = sin(_wobble_time * 5.0 - 0.4) * 0.12 * wobble_intensity
		_tail_seg2.rotation = _tail_seg2_base + Vector3(tail_accel * 0.5, 0, seg2_wobble)
	
	if _tail_seg3:
		var seg3_wobble: float = sin(_wobble_time * 5.0 - 0.8) * 0.1 * wobble_intensity
		_tail_seg3.rotation = _tail_seg3_base + Vector3(tail_accel * 0.3, 0, seg3_wobble)
	
	# === CHIN STRAP ===
	# Strap swings loosely
	var strap_wobble_x: float = sin(_wobble_time * 7.0) * 0.2 * wobble_intensity
	var strap_wobble_z: float = cos(_wobble_time * 5.5) * 0.15 * wobble_intensity
	var strap_accel: float = -_smoothed_accel.z * 0.025
	
	if _strap_loose:
		_strap_loose.rotation = _strap_base + Vector3(strap_accel + strap_wobble_x, 0, strap_wobble_z)


func _find_bike() -> RigidBody3D:
	# Walk up the tree to find the bike RigidBody3D
	var node: Node = get_parent()
	while node:
		if node is RigidBody3D:
			return node as RigidBody3D
		node = node.get_parent()
	return null
