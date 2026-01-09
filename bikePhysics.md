# Bike Physics System Documentation

This document describes the complete physics system for the bike controller, including all parameters, interactions with the world, user input handling, and implementation details.

---

## Table of Contents

1. [Overview](#overview)
2. [Core Architecture](#core-architecture)
3. [Input Controls](#input-controls)
4. [Physics Parameters](#physics-parameters)
5. [Ground Detection & Normal Smoothing](#ground-detection--normal-smoothing)
6. [Traction System](#traction-system)
7. [Stability & Balance System](#stability--balance-system)
8. [Suspension System](#suspension-system)
9. [Steering & Handling](#steering--handling)
10. [Air Control](#air-control)
11. [Drift System](#drift-system)
12. [Camera System](#camera-system)
13. [Visual & Animation System](#visual--animation-system)
14. [Platform Interaction](#platform-interaction)
15. [Scene Structure](#scene-structure)

---

## Overview

The bike uses a **Trials-style RigidBody3D physics model** with real physics-based movement supporting:
- Wheelies and stoppies
- Full rotation tricks (flips, spins)
- Slope-aware traction
- Dynamic stability modes
- Soft-body suspension simulation

**Key Design Principles:**
- Forces are applied at wheel contact points for natural torque generation
- Ground frame calculations ensure physics work correctly on slopes
- Torque-based stabilization works WITH the physics solver (not against it)
- Speed-adaptive parameters for responsiveness at all velocities

---

## Core Architecture

The bike controller extends `RigidBody3D` and uses two main update loops:

### `_integrate_forces(state: PhysicsDirectBodyState3D)`
Runs during physics step - handles physics-critical operations:
1. Compute ground frame (coordinate system relative to ground surface)
2. Update stability mode state machine
3. Apply traction forces
4. Apply stabilization torques
5. Apply roll damping

```gdscript
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
    
    # Force-based traction in ground frame
    _apply_traction(state, throttle, brake, drifting)
    
    # Torque-based stabilization
    _apply_stabilization(state, steer)
    
    # Roll damping - prevents sideways tip accumulation
    _apply_roll_damping(state)
```

### `_physics_process(delta: float)`
Runs every physics tick - handles gameplay logic:
1. Ground detection via wheel probes
2. Suspension force calculation
3. Center of mass adjustment
4. Drive force application
5. Steering and lean torques
6. Speed limiting
7. Jump handling
8. Camera and animation updates

---

## Input Controls

### Mapped Actions (from `project.godot`)

| Action | Key | Purpose |
|--------|-----|---------|
| `accelerate` | W | Throttle + forward lean |
| `brake` | S | Brake/reverse + backward lean |
| `steer_left` | A | Turn left |
| `steer_right` | D | Turn right |
| `jump` | Space | Jump (perpendicular to bike bottom) |
| `lean_back` | Q | Wheelie lean (4x lean_torque) |
| `interact` | E | Game interaction |
| Drift | Shift (physical) | Enable drift mode |
| Reset | R (physical) | Reset bike in place |
| Mouse | Move | Camera look |
| Escape | ui_cancel | Toggle mouse capture |

### Input Processing

```gdscript
# In _physics_process:
var throttle: float = 1.0 if Input.is_action_pressed("accelerate") else 0.0
var tilt: float = Input.get_axis("brake", "accelerate")  # W = +1, S = -1
var steer: float = Input.get_axis("steer_right", "steer_left")
var drifting: bool = Input.is_physical_key_pressed(KEY_SHIFT)
var lean_back: float = 1.0 if Input.is_action_pressed("lean_back") else 0.0
```

---

## Physics Parameters

### Movement

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `engine_force` | 2100.0 N | Forward thrust force |
| `brake_force` | 1000.0 N | Braking force |
| `max_speed` | 21.0 m/s | Engine-limited top speed on flat ground |
| `downhill_speed_bonus` | 1.5x | Max speed multiplier when going downhill |

### Momentum

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `bike_mass` | 95.0 kg | Total mass of bike+rider |
| `bike_drag` | 0.08 | Linear damping (lower = smoother landings) |

### Steering

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `steer_torque` | 250.0 | Yaw torque for turning |
| `steer_speed_factor` | 0.4 | Steering reduction at high speed |

### Balance/Lean

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `lean_torque` | 400.0 | Pitch torque from W/S input |

**Note**: `pitch_stabilization` has been removed - pitch correction is now handled by the ground-relative `_apply_stabilization()` system to avoid conflicts on slopes.

### Arcade Traction

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `traction_accel_time` | 0.15s | Time to reach target speed when throttling |
| `lateral_grip_strength` | 12.0 | Lateral velocity damping (normal mode) |
| `drift_lateral_grip` | 2.0 | Reduced grip during drift |
| `max_traction_force` | 3000.0 N | Safety clamp for seam transitions |
| `drift_kickout` | 0.0 | Lateral impulse when starting drift |
| `drift_steer_boost` | 1.3x | Steering multiplier during drift |
| `max_lean_angle` | 0.6 rad (~35°) | Maximum visual lean angle |

### Slope-Aware Traction (True Free-Roll)

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `idle_brake_time` | 1.5s | Time to stop on FLAT ground only |

**Note**: `downhill_roll_factor` and `uphill_grip_strength` have been removed. The bike now uses true free-roll on slopes - no traction force is applied when there's no input on slopes, letting gravity and friction handle movement naturally.

### Stabilization

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `lean_into_turn_angle` | 0.15 rad (~8.5°) | How much bike leans into turns |
| `max_stabilization_torque` | 800.0 | Hard clamp for stability torques |
| `min_lean_speed` | 2.0 m/s | No turn lean below this speed |
| `normal_upright_strength` | 500.0 | Strong stabilization for normal driving |
| `normal_roll_damping` | 150.0 | Moderate damping for smooth stabilization (direct Nm/(rad/s)) |
| `steep_upright_strength` | 40.0 | Very weak when sideways on steep slope (allows tipping) |
| `steep_roll_damping` | 10.0 | Low damping allows natural falling (direct Nm/(rad/s)) |
| `grounded_com_offset` | -0.05 | Slight COM lowering when grounded (less artificial stability) |

**Note**: Damping values are now direct Nm/(rad/s) without mass multiplier.

### Stability Mode Thresholds

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `steep_slope_threshold` | 0.5 | ground_up.y below this = steep (~60°) |
| `across_slope_threshold` | 0.7 | Movement perpendicular to downhill |
| `wall_tip_speed` | 6.0 m/s | Below this + steep + sideways = can tip (raised for forgiving gameplay) |
| `crash_impact_threshold` | 15.0 | Impulse to trigger crash window |
| `crash_window_duration` | 0.5s | Duration of reduced stabilization |

### Ground Probing

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `normal_smoothing_base` | 5 frames | Smoothing at low speed (~42ms at 120Hz) |
| `normal_smoothing_min` | 2 frames | Smoothing at high speed (~17ms) |

### Jump

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `jump_impulse` | 600.0 | Impulse perpendicular to bike bottom |

### Suspension

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `suspension_stiffness` | 1200.0 N/m | Spring force - tuned for visible travel with bounce |
| `suspension_damping` | 8.0 | Damper - lower for more bounce, paired with higher stiffness |
| `suspension_rest_length` | 0.55 | Neutral suspension position |
| `max_suspension_travel` | 0.35 | Max compression/extension |

### Tire Grip

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `tire_grip` | 5.0 | How well tires climb obstacles |
| `front_climb_force` | 1200.0 N | Force to help front wheel climb bumps |
| `bump_pop_strength` | 0.3 | Pop assist strength when stuck (0-1) |

### Camera

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `base_fov` | 65.0° | Base field of view |
| `camera_distance` | 5.5 | Distance behind bike |
| `camera_height` | 3.0 | Height above bike |
| `camera_angle` | 16.0° | Pitch angle (how much camera looks down) |
| `fov_boost` | 1.0 | Max FOV increase at top speed |

### Visual Effects

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `angular_damping_value` | 0.8 | Rotation resistance |
| `air_pitch_torque` | 350.0 | Air flip responsiveness |
| `air_yaw_torque` | 180.0 | Air spin responsiveness |
| `landing_squash_amount` | 0.10 | Visual squash on landing |
| `disable_visual_effects` | false | Debug: disable visual lean/squash |

### Legacy Systems (Toggles)

| Parameter | Default Value | Description |
|-----------|---------------|-------------|
| `enable_legacy_bump_assist` | false | Legacy bump climbing assistance |
| `enable_legacy_climb_assist` | false | Legacy edge climbing assistance |

---

## Ground Detection & Normal Smoothing

### Wheel Probes
Two `ShapeCast3D` nodes detect ground contact:
- **FrontWheelProbe**: Position (0, 0.38, 0.65), sphere radius 0.32, cast down 0.95
- **RearWheelProbe**: Position (0, 0.38, -0.6), sphere radius 0.32, cast down 0.95

```gdscript
func _check_ground() -> void:
    # Speed-adaptive smoothing window
    var current_speed: float = linear_velocity.length()
    var speed_ratio: float = clampf(current_speed / max_speed, 0.0, 1.0)
    var smoothing_frames: int = int(lerpf(float(normal_smoothing_base), 
                                           float(normal_smoothing_min), speed_ratio))
    
    # Front wheel probe
    _front_grounded = _front_wheel_probe.is_colliding()
    if _front_grounded:
        _front_contact_point = _front_wheel_probe.get_collision_point(0)
        _front_normal = _front_wheel_probe.get_collision_normal(0)
        
        # Rolling average for normal smoothing
        _front_normal_buffer.append(_front_normal)
        if _front_normal_buffer.size() > smoothing_frames:
            _front_normal_buffer.pop_front()
        _smoothed_front_normal = _compute_smoothed_normal(_front_normal_buffer)
    else:
        # Just left ground - flush buffer
        if was_front_grounded:
            _front_normal_buffer.clear()
        _smoothed_front_normal = _smoothed_front_normal.lerp(Vector3.UP, 0.3)
    
    # Same logic for rear wheel...
```

### Ground Frame Computation

Creates a coordinate system aligned to the ground surface:

```gdscript
func _compute_ground_frame(state: PhysicsDirectBodyState3D) -> void:
    if not _front_grounded and not _rear_grounded:
        _is_grounded = false
        _ground_up = _ground_up.lerp(Vector3.UP, 0.3)  # Blend to world up
        _surface_velocity = Vector3.ZERO
        _relative_velocity = state.linear_velocity
        return
    
    _is_grounded = true
    _surface_velocity = _get_surface_velocity()  # For moving platforms
    _relative_velocity = state.linear_velocity - _surface_velocity
    
    # Blend normals: favor rear when both grounded (70/30)
    if _front_grounded and _rear_grounded:
        blended_normal = (_smoothed_rear_normal * 0.7 + _smoothed_front_normal * 0.3).normalized()
    elif _rear_grounded:
        blended_normal = _smoothed_rear_normal
    else:
        blended_normal = _smoothed_front_normal
    
    _ground_up = blended_normal
    
    # Project bike forward onto ground plane
    var bike_forward: Vector3 = global_transform.basis.z  # +Z is forward
    var projected: Vector3 = bike_forward - _ground_up * bike_forward.dot(_ground_up)
    
    _ground_forward = projected.normalized()
    _ground_right = _ground_forward.cross(_ground_up).normalized()
```

---

## Traction System

### True Free-Roll Traction Model

The traction system handles acceleration, braking, and lateral grip in the ground frame. **On slopes with no input, the bike rolls freely with gravity.**

```gdscript
func _apply_traction(state: PhysicsDirectBodyState3D, throttle: float, 
                     brake: float, drifting: bool) -> void:
    if not _is_grounded:
        return
    
    # Decompose velocity into ground frame
    var forward_speed: float = _relative_velocity.dot(_ground_forward)
    var lateral_speed: float = _relative_velocity.dot(_ground_right)
    
    # Calculate slope direction
    var slope_factor: float = _ground_forward.dot(Vector3.DOWN)
    slope_factor = clampf(slope_factor, -0.9, 0.9)
    
    # === FORWARD TRACTION ===
    var target_speed: float = 0.0
    var accel_time: float = traction_accel_time
    
    if throttle > 0:
        target_speed = throttle * max_speed
    elif brake > 0:
        target_speed = -brake * max_speed * 0.3  # Reverse is slower
    else:
        # === TRUE FREE-ROLL: No input = no traction force ===
        var abs_slope: float = absf(slope_factor)
        
        if abs_slope > 0.03:
            # On any slope: ZERO traction force, let physics handle it
            target_speed = forward_speed  # Match current speed = no force
        else:
            # On flat ground: gentle braking to stop
            target_speed = 0.0
            accel_time = idle_brake_time
    
    var speed_error: float = target_speed - forward_speed
    var desired_accel: float = speed_error / accel_time
    var traction_force: float = desired_accel * mass
    
    # Clamp to engine/brake limits
    traction_force = clampf(traction_force, -max_traction_force, max_traction_force)
    
    state.apply_central_force(_ground_forward * traction_force)
    
    # === LATERAL DAMPING ===
    var grip: float = drift_lateral_grip if drifting else lateral_grip_strength
    var lateral_force: float = -lateral_speed * grip * mass
    lateral_force = clampf(lateral_force, -max_traction_force, max_traction_force)
    state.apply_central_force(_ground_right * lateral_force)
```

**Key change**: On slopes (>3% grade), no traction force is applied when idling. Gravity and friction naturally handle the rolling behavior.

### Drive Force Application (Physics Process)

Engine force is applied at the rear wheel contact point for natural wheelie torque:

```gdscript
if throttle > 0 and _rear_grounded:
    var current_speed: float = linear_velocity.length()
    var speed_ratio: float = clamp(current_speed / max_speed, 0.0, 1.0)
    var accel_curve: float = 1.0 - (speed_ratio * speed_ratio * 0.6)  # Quadratic falloff
    
    # Project forward onto ground plane for slope climbing
    var drive_forward: Vector3 = forward
    if _rear_normal.y < 0.99:
        var ground_forward: Vector3 = (forward - _rear_normal * forward.dot(_rear_normal)).normalized()
        var climb_blend: float = 1.0 - clamp(current_speed / 8.0, 0.0, 0.7)
        drive_forward = forward.lerp(ground_forward, climb_blend).normalized()
    
    var force_vec: Vector3 = drive_forward * throttle * engine_force * accel_curve
    var force_pos: Vector3 = _rear_contact_point - global_position
    apply_force(force_vec, force_pos)
```

### Braking

Braking force is distributed 70% front / 30% rear:

```gdscript
if tilt < 0 and throttle == 0:
    var dominated_forward: float = linear_velocity.dot(forward)
    if dominated_forward > 1.0:
        var brake_dir: Vector3 = -linear_velocity.normalized()
        if _front_grounded:
            var force_pos: Vector3 = _front_contact_point - global_position
            apply_force(brake_dir * abs(tilt) * brake_force * 0.7, force_pos)
        if _rear_grounded:
            var force_pos: Vector3 = _rear_contact_point - global_position
            apply_force(brake_dir * abs(tilt) * brake_force * 0.3, force_pos)
    elif _rear_grounded:
        # Reverse
        var reverse_force: Vector3 = -forward * abs(tilt) * engine_force * 0.8
        var force_pos: Vector3 = _rear_contact_point - global_position
        apply_force(reverse_force, force_pos)
```

### Speed Limiting

Soft speed cap that allows gravity-assisted downhill speeds:

```gdscript
var effective_max_speed: float = max_speed

# Calculate downhill factor
if wheels_touching and speed > 0.5:
    var ground_normal: Vector3 = _rear_normal if _rear_grounded else _front_normal
    var slope_dir: Vector3 = Vector3(ground_normal.x, 0, ground_normal.z)
    if slope_dir.length() > 0.01:
        slope_dir = slope_dir.normalized()
        var vel_horizontal: Vector3 = Vector3(linear_velocity.x, 0, linear_velocity.z).normalized()
        var slope_alignment: float = vel_horizontal.dot(slope_dir)
        var slope_steepness: float = 1.0 - ground_normal.y
        downhill_factor = maxf(0.0, slope_alignment) * slope_steepness

effective_max_speed = max_speed + (max_speed * (downhill_speed_bonus - 1.0) * downhill_factor)

if throttle > 0 and downhill_factor < 0.1:
    # Hard cap when throttling on flat/uphill
    if speed > max_speed:
        linear_velocity = linear_velocity.normalized() * max_speed
elif speed > effective_max_speed:
    # Soft cap downhill
    linear_velocity = linear_velocity.normalized() * effective_max_speed
```

---

## Stability & Balance System

### Stability Mode State Machine

```gdscript
enum StabilityMode { AIR, NORMAL_GROUNDED, STEEP_SIDEWAYS, CRASH_WINDOW }
```

| Mode | Condition | Stabilization Strength |
|------|-----------|------------------------|
| `AIR` | Not grounded | None (full trick control) |
| `NORMAL_GROUNDED` | On normal terrain | Strong (500.0) - bike never falls |
| `STEEP_SIDEWAYS` | Steep + across slope + slow | Very weak (40.0) + tip-over assist |
| `CRASH_WINDOW` | After impact | Minimal (4.0) - prevents instant recovery |

### Tip-Over Assist

When in `STEEP_SIDEWAYS` mode and the bike is tilted past a threshold angle (~25°), a destabilizing torque is applied to accelerate the natural fall. This creates the "angle + speed" behavior where:
- **At high speed (>6 m/s)**: Bike stays stable even on steep sideways slopes
- **At low speed (<6 m/s)**: Bike tips over naturally when tilted on steep slopes

```gdscript
func _update_stability_mode(state: PhysicsDirectBodyState3D) -> void:
    # Impact detection
    var velocity_delta: Vector3 = state.linear_velocity - _prev_velocity
    var impact_magnitude: float = velocity_delta.length() / delta
    
    if impact_magnitude > crash_impact_threshold * 100.0:
        _crash_window_timer = crash_window_duration
        _stability_mode = StabilityMode.CRASH_WINDOW
        return
    
    if _crash_window_timer > 0:
        _stability_mode = StabilityMode.CRASH_WINDOW
        return
    
    if not _is_grounded:
        _stability_mode = StabilityMode.AIR
        return
    
    # Check for STEEP_SIDEWAYS conditions
    var is_steep: bool = _ground_up.y < steep_slope_threshold
    _across_slope_factor = _compute_across_slope_factor()
    var is_across: bool = _across_slope_factor > across_slope_threshold
    var is_slow: bool = _relative_velocity.length() < wall_tip_speed
    
    if is_steep and is_across and is_slow:
        _stability_mode = StabilityMode.STEEP_SIDEWAYS
    else:
        _stability_mode = StabilityMode.NORMAL_GROUNDED
```

### Torque-Based Stabilization

Uses physics torque (not direct rotation writes) for smooth stability. Includes tip-over assist for steep sideways slopes.

```gdscript
func _apply_stabilization(state: PhysicsDirectBodyState3D, steer_input: float) -> void:
    if _stability_mode == StabilityMode.AIR:
        return  # No stabilization in air
    
    var bike_up: Vector3 = global_transform.basis.y
    
    # === TIP-OVER ASSIST ===
    # In STEEP_SIDEWAYS mode, when tilted past threshold, apply destabilizing torque
    if _stability_mode == StabilityMode.STEEP_SIDEWAYS:
        var tilt_from_ground: float = 1.0 - bike_up.dot(_ground_up)
        if tilt_from_ground > 0.3:  # ~25 degrees
            # Apply torque in fall direction to accelerate tip-over
            # ... (tip-over logic)
            return  # Skip normal stabilization when actively tipping
    
    # Target includes lean into turns
    var lean_offset: float = 0.0
    if _relative_velocity.length() > min_lean_speed:
        lean_offset = steer_input * lean_into_turn_angle
    
    var target_up: Vector3 = _ground_up
    if absf(lean_offset) > 0.01:
        target_up = _ground_up.rotated(_ground_forward, lean_offset)
    
    # Calculate error
    var error_axis: Vector3 = bike_up.cross(target_up)
    var error_angle: float = asin(clampf(error_axis.length(), -1.0, 1.0))
    error_axis = error_axis.normalized()
    
    # Mode-based strength
    match _stability_mode:
        StabilityMode.NORMAL_GROUNDED:
            upright_strength = 500.0   # Strong
            damping_strength = 150.0   # Direct Nm/(rad/s)
        StabilityMode.STEEP_SIDEWAYS:
            upright_strength = 40.0    # Very weak
            damping_strength = 10.0    # Direct Nm/(rad/s)
    
    # Corrective torque (NOTE: damping no longer multiplied by mass)
    var correction_magnitude: float = error_angle * upright_strength
    var ang_vel_component: float = state.angular_velocity.dot(error_axis)
    var damping_magnitude: float = -ang_vel_component * damping_strength
    
    var total_torque: float = clampf(correction_magnitude + damping_magnitude,
                                      -max_stabilization_torque, max_stabilization_torque)
    
    state.apply_torque(error_axis * total_torque)
```

**Key change**: Damping is now direct Nm/(rad/s) without mass multiplier, allowing proper tip-over behavior.

### Roll Damping

Dedicated system to prevent sideways tip accumulation from bumps:

```gdscript
func _apply_roll_damping(state: PhysicsDirectBodyState3D) -> void:
    if _stability_mode == StabilityMode.AIR:
        return
    
    var roll_axis: Vector3 = global_transform.basis.z  # Forward = roll axis
    var roll_rate: float = state.angular_velocity.dot(roll_axis)
    
    var damping_strength: float
    match _stability_mode:
        StabilityMode.NORMAL_GROUNDED:
            damping_strength = normal_roll_damping   # 150.0 Nm/(rad/s)
        StabilityMode.STEEP_SIDEWAYS:
            damping_strength = steep_roll_damping    # 10.0 Nm/(rad/s)
        StabilityMode.CRASH_WINDOW:
            damping_strength = steep_roll_damping * 0.3
    
    # NOTE: Removed mass multiplier - damping_strength is direct Nm/(rad/s)
    var damping_torque: Vector3 = -roll_axis * roll_rate * damping_strength
    var max_roll_damping_torque: float = max_stabilization_torque * 0.5
    
    if damping_torque.length() > max_roll_damping_torque:
        damping_torque = damping_torque.normalized() * max_roll_damping_torque
    
    state.apply_torque(damping_torque)
```

### Dynamic Center of Mass

Center of mass lowers when grounded for stability, returns to normal in air for trick responsiveness:

```gdscript
func _update_center_of_mass(delta: float) -> void:
    var target_y: float = grounded_com_offset if _is_grounded else 0.0  # -0.15 or 0
    var current_com: Vector3 = center_of_mass
    var new_y: float = lerpf(current_com.y, target_y, 10.0 * delta)
    center_of_mass = Vector3(current_com.x, new_y, current_com.z)
```

---

## Suspension System

Soft-body spring-damper suspension at each wheel:

```gdscript
func _apply_suspension(delta: float) -> void:
    _prev_front_compression = _front_suspension_compression
    _prev_rear_compression = _rear_suspension_compression
    
    if _front_grounded:
        var probe_origin: Vector3 = _front_wheel_probe.global_position
        var probe_hit: Vector3 = _front_contact_point
        var current_length: float = probe_origin.distance_to(probe_hit)
        
        # Compression = rest - current (positive = compressed)
        _front_suspension_compression = suspension_rest_length - current_length
        _front_suspension_compression = clamp(_front_suspension_compression, 
                                               -max_suspension_travel, max_suspension_travel)
        
        # Compression velocity for damping
        var compression_velocity: float = (_front_suspension_compression - _prev_front_compression) / delta
        
        # Spring-damper force: F = k*x - c*v
        var spring_force: float = suspension_stiffness * _front_suspension_compression
        var damping_force: float = suspension_damping * compression_velocity
        var total_force: float = spring_force - damping_force
        
        if total_force > 0:
            var force_vec: Vector3 = _front_normal * total_force
            var force_pos: Vector3 = _front_contact_point - global_position
            apply_force(force_vec, force_pos)
        
        # Visual wheel offset
        _front_wheel_visual_offset = -_front_suspension_compression
    else:
        # Extend to rest when airborne
        _front_suspension_compression = lerp(_front_suspension_compression, 0.0, 5.0 * delta)
        _front_wheel_visual_offset = lerp(_front_wheel_visual_offset, 0.0, 5.0 * delta)
    
    # Same logic for rear wheel...
```

---

## Steering & Handling

### Ground Steering

```gdscript
if wheels_touching and can_steer and abs(steer) > 0.01 and not drifting:
    var current_speed: float = linear_velocity.length()
    
    # Reduce at high speed
    var high_speed_factor: float = 1.0 - (current_speed / max_speed) * steer_speed_factor
    high_speed_factor = clamp(high_speed_factor, 0.4, 1.0)
    
    # Boost at low speed (1.5x at standstill, 1.0x at 5+ m/s)
    var low_speed_boost: float = 1.0 + 0.5 * (1.0 - clamp(current_speed / 5.0, 0.0, 1.0))
    
    var speed_factor: float = high_speed_factor * low_speed_boost
    var throttle_boost: float = 1.0 + abs(throttle) * 0.5
    
    # Camera alignment boost
    var camera_offset: float = _camera_yaw - global_rotation.y
    # Normalize to [-PI, PI]
    while camera_offset > PI: camera_offset -= TAU
    while camera_offset < -PI: camera_offset += TAU
    var look_alignment: float = camera_offset * steer
    var camera_boost: float = 1.0 + clamp(look_alignment, 0.0, 0.5)
    
    # Invert when reversing
    var effective_steer: float = -steer if moving_backward else steer
    
    # Reduce on steep slopes
    var slope_steer_factor: float = 1.0 - (slope_factor * 0.7)
    
    # Use ground normal as steering axis
    var steering_up: Vector3 = _smoothed_rear_normal if _rear_grounded else _smoothed_front_normal
    
    var steer_torque_applied: Vector3 = steering_up * effective_steer * steer_torque * \
                                         speed_factor * throttle_boost * camera_boost * slope_steer_factor
    apply_torque(steer_torque_applied)
```

### Lean Control (W/S Tilt)

```gdscript
var horizontal_right: Vector3 = Vector3(right.x, 0, right.z).normalized()

if not _bump_assist_active:
    var lean_torque_applied: Vector3 = horizontal_right * tilt * lean_torque
    apply_torque(lean_torque_applied)

# Q key wheelie (4x lean_torque)
if lean_back > 0:
    var wheelie_torque: Vector3 = horizontal_right * -lean_back * lean_torque * 4.0
    apply_torque(wheelie_torque)
```

### Pitch Stabilization (Grounded)

```gdscript
if wheels_touching and abs(tilt) < 0.1 and lean_back < 0.1 and not _bump_assist_active:
    var current_pitch: float = global_rotation.x
    apply_torque(right * -current_pitch * pitch_stabilization)
```

---

## Air Control

When not grounded, player has full rotation control:

```gdscript
# Air pitch (W/S) - flip control
apply_torque(right * tilt * air_pitch_torque)

# Q key in air (backflip)
if lean_back > 0:
    apply_torque(right * -lean_back * air_pitch_torque)

# Air yaw (A/D) - spin control
var up: Vector3 = global_transform.basis.y
apply_torque(up * steer * air_yaw_torque)
```

---

## Drift System

Hold Shift to enable drift mode with reduced grip and boosted steering:

```gdscript
if drifting:
    # Kickout impulse on drift entry
    if not _was_drifting and linear_velocity.length() > 5.0:
        if abs(steer) > 0.1:
            var kickout_strength: float = abs(steer) * drift_kickout * mass
            var drift_ground_up: Vector3 = _smoothed_rear_normal if _rear_grounded else _smoothed_front_normal
            var drift_ground_fwd: Vector3 = (forward - drift_ground_up * forward.dot(drift_ground_up)).normalized()
            var drift_ground_right: Vector3 = drift_ground_fwd.cross(drift_ground_up).normalized()
            var kickout_impulse: Vector3 = drift_ground_right * -steer * kickout_strength
            apply_central_impulse(kickout_impulse)
        _drift_camera_delay = 0.3
    
    # Reduced lateral grip (drift_lateral_grip = 2.0 vs lateral_grip_strength = 12.0)
    var lateral_vel: float = linear_velocity.dot(right)
    if abs(lateral_vel) > 0.1:
        var grip_force: Vector3 = -right * lateral_vel * drift_lateral_grip
        apply_central_force(grip_force)
    
    # Boosted steering
    var drift_steer_torque: Vector3 = steering_up * steer * steer_torque * drift_steer_boost
    apply_torque(drift_steer_torque)
```

---

## Camera System

### Camera Setup

The camera is independent of bike rotation (top_level = true), preventing it from flipping when the bike does:

```gdscript
func _ready() -> void:
    _camera_pivot.top_level = true
    _camera_pivot.global_position = global_position + Vector3(0, 1, 0)
```

### Mouse Look

```gdscript
func _handle_mouse_look(event: InputEventMouseMotion) -> void:
    var sensitivity: float = 0.002
    _camera_yaw -= event.relative.x * sensitivity
    _camera_pivot.rotation.y = _camera_yaw
    _mouse_control_strength = 1.0
    _mouse_hold_timer = 0.5  # 500ms before auto-follow returns
```

### Auto-Follow

```gdscript
func _update_camera(delta: float) -> void:
    # Decay mouse control after hold timer
    if _mouse_hold_timer > 0:
        _mouse_hold_timer -= delta
    else:
        _mouse_control_strength = maxf(0.0, _mouse_control_strength - 0.7 * delta)
    
    # Dynamic FOV (speed sensation)
    var speed_ratio: float = clamp(speed / max_speed, 0.0, 1.0)
    var target_fov: float = base_fov + (speed_ratio * speed_ratio * fov_boost)
    _camera.fov = lerp(_camera.fov, target_fov, 5.0 * delta)
    
    # Position tracking
    var target_pos: Vector3 = global_position + Vector3(0, 1, 0)
    _camera_pivot.global_position = _camera_pivot.global_position.lerp(target_pos, 10.0 * delta)
    
    // Height drops at speed
    var height_reduction: float = 0.8
    var target_height: float = camera_height - (speed_ratio * height_reduction)
    _camera.position.y = lerp(_camera.position.y, target_height, 3.0 * delta)
    _camera.position.z = lerp(_camera.position.z, -camera_distance, 3.0 * delta)
    
    // Auto-follow logic
    if is_grounded and bike_upright:
        if horiz_speed > 2.0:
            target_yaw = atan2(horiz_vel.x, horiz_vel.z)  // Follow velocity
        else:
            target_yaw = atan2(fwd.x, fwd.z)  // Follow heading
    elif horiz_speed > 8.0:
        target_yaw = atan2(horiz_vel.x, horiz_vel.z)
    
    // Blend with mouse control
    var effective_speed: float = camera_speed * (1.0 - _mouse_control_strength)
    _camera_yaw = lerp_angle(_camera_yaw, target_yaw, effective_speed * delta)
```

---

## Visual & Animation System

### Landing Squash

```gdscript
if wheels_touching and _was_airborne:
    _landing_squash = landing_squash_amount  // 0.10
    _landing_grace_timer = 0.3  // Reduced alignment for smooth landing

_landing_squash = lerp(_landing_squash, 0.0, 10.0 * delta)
```

### Visual Lean (Counter-Steer)

```gdscript
if _front_grounded and _rear_grounded and speed > 1.0 and not moving_backward:
    // Lean opposite to slip angle (counter-steer visual)
    var vel_horizontal: Vector3 = Vector3(linear_velocity.x, 0, linear_velocity.z)
    var forward_horizontal: Vector3 = Vector3(forward.x, 0, forward.z).normalized()
    
    if vel_horizontal.length() > 2.0:
        var slip_angle: float = forward_horizontal.signed_angle_to(vel_horizontal.normalized(), Vector3.UP)
        var lean_multiplier: float = 2.5 if drifting else 1.5
        target_visual_lean = slip_angle * lean_multiplier
        target_visual_lean = clamp(target_visual_lean, -max_lean_angle, max_lean_angle)
    
    // Add steering lean
    var steer_lean: float = -steer * 0.4
    target_visual_lean = clamp(target_visual_lean + steer_lean, -max_lean_angle, max_lean_angle)

// Rear follows front with delay
_visual_lean = lerp(_visual_lean, target_visual_lean, lean_speed * delta)
_rear_lean = lerp(_rear_lean, _visual_lean, 6.0 * delta)
```

### Bike Animation

```gdscript
func _animate_bike(delta: float) -> void:
    if not disable_visual_effects:
        _bike_model.rotation.z = _rear_lean
        if _front_assembly:
            _front_assembly.rotation.z = _visual_lean - _rear_lean
        
        // Landing squash
        _bike_model.scale.y = 1.0 - _landing_squash
        _bike_model.scale.x = 1.0 + _landing_squash * 0.5
        _bike_model.scale.z = 1.0 + _landing_squash * 0.5
    
    // Wheel rotation
    var wheel_circumference: float = 2.0 * PI * WHEEL_RADIUS  // 0.35
    var rotations_per_second: float = speed / wheel_circumference
    if linear_velocity.dot(forward) < 0:
        rotations_per_second = -rotations_per_second
    _wheel_rotation += rotations_per_second * 2.0 * PI * delta
    
    _front_wheel.rotation.x = _wheel_rotation
    _front_wheel.position.y = 0.35 + _front_wheel_visual_offset
    _rear_wheel.rotation.x = _wheel_rotation
    _rear_wheel.position.y = 0.35 + _rear_wheel_visual_offset
    
    // Handlebar steering visual
    _steering_angle = lerp(_steering_angle, steer_input * 0.5, 10.0 * delta)
    _front_assembly.rotation.y = _steering_angle
    
    // Pedal animation when throttling
    if throttle and grounded:
        var pedal_speed: float = 8.0
        _pedal_arm_left.rotation.y = sin(Time.get_ticks_msec() * 0.01 * pedal_speed) * 0.5
        _pedal_arm_right.rotation.y = sin(Time.get_ticks_msec() * 0.01 * pedal_speed + PI) * 0.5
```

---

## Platform Interaction

### Moving Platform Support

The traction system uses **relative velocity** to work correctly on moving platforms:

```gdscript
func _get_surface_velocity() -> Vector3:
    if not _front_grounded and not _rear_grounded:
        return Vector3.ZERO
    
    var probe: ShapeCast3D = _rear_wheel_probe if _rear_grounded else _front_wheel_probe
    var collider: Object = probe.get_collider(0)
    
    if collider is StaticBody3D:
        return Vector3.ZERO
    
    // For AnimatableBody3D / RigidBody3D, compute from position delta
    var node: Node3D = collider as Node3D
    var node_id: int = node.get_instance_id()
    var current_pos: Vector3 = node.global_position
    var dt: float = get_physics_process_delta_time()
    
    if not _platform_prev_pos.has(node_id):
        _platform_prev_pos[node_id] = current_pos
        return Vector3.ZERO
    
    var prev_pos: Vector3 = _platform_prev_pos[node_id]
    _platform_prev_pos[node_id] = current_pos
    
    return (current_pos - prev_pos) / dt
```

---

## Scene Structure

### Collision Shapes

```
Bike (RigidBody3D)
├── BodyCollision (BoxShape3D: 0.3 × 0.4 × 0.8 at Y=0.7)
├── FrontWheelCollision (SphereShape3D: r=0.38 at Z=0.65, Y=0.38)
└── RearWheelCollision (SphereShape3D: r=0.38 at Z=-0.6, Y=0.38)
```

### Wheel Probes

```
├── FrontWheelProbe (ShapeCast3D)
│   ├── Position: (0, 0.38, 0.65)
│   ├── Shape: Sphere r=0.32
│   └── Target: (0, -0.95, 0)
│
└── RearWheelProbe (ShapeCast3D)
    ├── Position: (0, 0.38, -0.6)
    ├── Shape: Sphere r=0.32
    └── Target: (0, -0.95, 0)
```

### Visual Model Hierarchy

```
BikeModel (Node3D)
├── TopTube, DownTube, SeatTube, ChainStays, SeatStays (frame)
├── SeatPost, Seat
├── FrontAssembly (Node3D - rotates for steering)
│   ├── HeadTube, Forks, HandleBars, Grips
│   └── FrontWheel (Node3D - rotates for rolling)
│       ├── Tire, Hub, Spokes
├── RearWheel (Node3D - rotates for rolling)
│   ├── Tire, Hub, Spokes
├── PedalArmLeft, PedalArmRight
└── Pedals
```

### Camera

```
CameraPivot (Node3D - top_level)
└── Camera3D
    ├── Position: (0, 4, -8)
    └── current = true
```

---

## Physics Configuration

From `project.godot`:

```ini
[physics]
common/physics_ticks_per_second=120
```

The game runs at **120 physics ticks per second** for responsive, smooth physics simulation.

### RigidBody3D Properties (from scene)

| Property | Value |
|----------|-------|
| mass | 60.0 (overridden to 95.0 by script) |
| friction | 0.8 (PhysicsMaterial) |
| contact_monitor | true |
| max_contacts_reported | 8 |
| linear_damp | 0.2 (overridden to 0.08 by script) |
| angular_damp | 0.8 |
| center_of_mass_mode | CUSTOM |

---

## Public API

```gdscript
# Get current speed in m/s
func get_current_speed() -> float

# Get horizontal speed (ignores Y velocity)
func get_horizontal_speed() -> float

# Check if any wheel is touching ground
func is_grounded() -> bool

# Check individual wheel contact
func is_front_grounded() -> bool
func is_rear_grounded() -> bool

# Teleport bike to position and reset all state
func reset_position(pos: Vector3) -> void

# Reset in place (keep XZ, lift slightly)
func reset_in_place() -> void

# Signal emitted when speed changes
signal speed_changed(speed: float)
```

---

## Summary

The bike physics system is a sophisticated trials-style controller built on:

1. **RigidBody3D** for realistic physics simulation
2. **Ground frame computation** for slope-aware behavior
3. **Stability state machine** with context-aware stabilization and tip-over assist
4. **True free-roll traction** - no artificial braking on slopes
5. **Properly-tuned spring-damper suspension** for visible bounce
6. **Independent camera** with auto-follow and manual override

Key design choices:
- Torque-based stabilization works WITH the physics solver
- **Tip-over assist** accelerates natural falling when slow on steep sideways slopes
- **True free-roll** on slopes - gravity handles downhill motion naturally
- Normal smoothing prevents jitter on rough terrain
- Relative velocity enables moving platform support
- Dynamic center of mass balances stability vs trick responsiveness
- **Damping without mass multiplier** allows proper tip-over physics
