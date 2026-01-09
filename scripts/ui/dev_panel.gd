extends CanvasLayer

## RigidBody3D Bike Dev Panel - real-time physics parameter tweaking

var _bike: BikeController = null

@onready var _panel: Control = $Panel
@onready var _speed_label: Label = $Panel/SpeedDisplay/SpeedLabel

# Movement sliders
@onready var _max_speed_slider: HSlider = $Panel/ScrollContainer/VBox/MovementSection/MaxSpeedSlider
@onready var _engine_force_slider: HSlider = $Panel/ScrollContainer/VBox/MovementSection/AccelerationSlider
@onready var _brake_slider: HSlider = $Panel/ScrollContainer/VBox/MovementSection/BrakeSlider

# Physics sliders
@onready var _mass_slider: HSlider = $Panel/ScrollContainer/VBox/MomentumSection/MassSlider
@onready var _linear_damp_slider: HSlider = $Panel/ScrollContainer/VBox/MomentumSection/DragSlider

# Steering/Balance sliders
@onready var _steer_torque_slider: HSlider = $Panel/ScrollContainer/VBox/SteeringSection/TurnSpeedSlider
@onready var _lean_torque_slider: HSlider = $Panel/ScrollContainer/VBox/SteeringSection/TurnInertiaSlider

# Arcade handling sliders
@onready var _vel_align_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/VelAlignSlider
@onready var _drift_grip_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/DriftGripSlider
@onready var _drift_kickout_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/DriftKickoutSlider
@onready var _drift_steer_boost_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/DriftSteerBoostSlider
@onready var _pitch_stab_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/PitchStabSlider
@onready var _wall_grip_speed_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/WallGripSpeedSlider

# Jump slider
@onready var _jump_slider: HSlider = $Panel/ScrollContainer/VBox/FrictionSection/JumpSlider

# Arcade feel sliders
@onready var _angular_damp_slider: HSlider = $Panel/ScrollContainer/VBox/ArcadeSection/AngularDampSlider
@onready var _air_pitch_slider: HSlider = $Panel/ScrollContainer/VBox/ArcadeSection/AirPitchSlider
@onready var _air_yaw_slider: HSlider = $Panel/ScrollContainer/VBox/ArcadeSection/AirYawSlider
@onready var _fov_boost_slider: HSlider = $Panel/ScrollContainer/VBox/ArcadeSection/FovBoostSlider
@onready var _landing_squash_slider: HSlider = $Panel/ScrollContainer/VBox/ArcadeSection/LandingSquashSlider
@onready var _disable_visual_checkbox: CheckBox = %DisableVisualCheckbox

# Camera sliders
@onready var _base_fov_slider: HSlider = $Panel/ScrollContainer/VBox/CameraSection/BaseFovSlider
@onready var _camera_dist_slider: HSlider = $Panel/ScrollContainer/VBox/CameraSection/CameraDistSlider
@onready var _camera_height_slider: HSlider = $Panel/ScrollContainer/VBox/CameraSection/CameraHeightSlider
@onready var _camera_angle_slider: HSlider = $Panel/ScrollContainer/VBox/CameraSection/CameraAngleSlider

# Suspension sliders
@onready var _susp_stiffness_slider: HSlider = $Panel/ScrollContainer/VBox/SuspensionSection/SuspStiffnessSlider
@onready var _susp_damping_slider: HSlider = $Panel/ScrollContainer/VBox/SuspensionSection/SuspDampingSlider
@onready var _susp_rest_slider: HSlider = $Panel/ScrollContainer/VBox/SuspensionSection/SuspRestSlider
@onready var _susp_travel_slider: HSlider = $Panel/ScrollContainer/VBox/SuspensionSection/SuspTravelSlider

# Tire grip sliders
@onready var _tire_grip_slider: HSlider = $Panel/ScrollContainer/VBox/SuspensionSection/TireGripSlider
@onready var _climb_force_slider: HSlider = $Panel/ScrollContainer/VBox/SuspensionSection/ClimbForceSlider
@onready var _bump_pop_slider: HSlider = $Panel/ScrollContainer/VBox/SuspensionSection/BumpPopSlider

# Value labels
@onready var _max_speed_value: Label = $Panel/ScrollContainer/VBox/MovementSection/MaxSpeedValue
@onready var _engine_force_value: Label = $Panel/ScrollContainer/VBox/MovementSection/AccelerationValue
@onready var _brake_value: Label = $Panel/ScrollContainer/VBox/MovementSection/BrakeValue
@onready var _mass_value: Label = $Panel/ScrollContainer/VBox/MomentumSection/MassValue
@onready var _linear_damp_value: Label = $Panel/ScrollContainer/VBox/MomentumSection/DragValue
@onready var _steer_torque_value: Label = $Panel/ScrollContainer/VBox/SteeringSection/TurnSpeedValue
@onready var _lean_torque_value: Label = $Panel/ScrollContainer/VBox/SteeringSection/TurnInertiaValue

# Arcade handling value labels
@onready var _vel_align_value: Label = $Panel/ScrollContainer/VBox/GripSection/VelAlignValue
@onready var _drift_grip_value: Label = $Panel/ScrollContainer/VBox/GripSection/DriftGripValue
@onready var _drift_kickout_value: Label = $Panel/ScrollContainer/VBox/GripSection/DriftKickoutValue
@onready var _drift_steer_boost_value: Label = $Panel/ScrollContainer/VBox/GripSection/DriftSteerBoostValue
@onready var _pitch_stab_value: Label = $Panel/ScrollContainer/VBox/GripSection/PitchStabValue
@onready var _wall_grip_speed_value: Label = $Panel/ScrollContainer/VBox/GripSection/WallGripSpeedValue

@onready var _jump_value: Label = $Panel/ScrollContainer/VBox/FrictionSection/JumpValue

# Arcade value labels
@onready var _angular_damp_value: Label = $Panel/ScrollContainer/VBox/ArcadeSection/AngularDampValue
@onready var _air_pitch_value: Label = $Panel/ScrollContainer/VBox/ArcadeSection/AirPitchValue
@onready var _air_yaw_value: Label = $Panel/ScrollContainer/VBox/ArcadeSection/AirYawValue
@onready var _fov_boost_value: Label = $Panel/ScrollContainer/VBox/ArcadeSection/FovBoostValue
@onready var _landing_squash_value: Label = $Panel/ScrollContainer/VBox/ArcadeSection/LandingSquashValue

# Camera value labels
@onready var _base_fov_value: Label = $Panel/ScrollContainer/VBox/CameraSection/BaseFovValue
@onready var _camera_dist_value: Label = $Panel/ScrollContainer/VBox/CameraSection/CameraDistValue
@onready var _camera_height_value: Label = $Panel/ScrollContainer/VBox/CameraSection/CameraHeightValue
@onready var _camera_angle_value: Label = $Panel/ScrollContainer/VBox/CameraSection/CameraAngleValue

# Suspension value labels
@onready var _susp_stiffness_value: Label = $Panel/ScrollContainer/VBox/SuspensionSection/SuspStiffnessValue
@onready var _susp_damping_value: Label = $Panel/ScrollContainer/VBox/SuspensionSection/SuspDampingValue
@onready var _susp_rest_value: Label = $Panel/ScrollContainer/VBox/SuspensionSection/SuspRestValue
@onready var _susp_travel_value: Label = $Panel/ScrollContainer/VBox/SuspensionSection/SuspTravelValue

# Tire grip value labels
@onready var _tire_grip_value: Label = $Panel/ScrollContainer/VBox/SuspensionSection/TireGripValue
@onready var _climb_force_value: Label = $Panel/ScrollContainer/VBox/SuspensionSection/ClimbForceValue
@onready var _bump_pop_value: Label = $Panel/ScrollContainer/VBox/SuspensionSection/BumpPopValue


@onready var _copy_button: Button = $Panel/ScrollContainer/VBox/CopyButton

func _ready() -> void:
	_panel.visible = false
	_connect_sliders()
	if _copy_button:
		_copy_button.pressed.connect(_on_copy_pressed)


func _process(_delta: float) -> void:
	if _bike and _speed_label:
		var grounded_status: String = ""
		if _bike.is_front_grounded() and _bike.is_rear_grounded():
			grounded_status = " [GROUNDED]"
		elif _bike.is_front_grounded():
			grounded_status = " [FRONT]"
		elif _bike.is_rear_grounded():
			grounded_status = " [REAR]"
		else:
			grounded_status = " [AIR]"
		_speed_label.text = "Speed: %.1f m/s%s" % [_bike.get_current_speed(), grounded_status]


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_panel()
		get_viewport().set_input_as_handled()


func toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
		_find_bike()
		_sync_sliders_from_bike()
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false


func _find_bike() -> void:
	_bike = _find_node_by_class(get_tree().root, "BikeController") as BikeController


func _find_node_by_class(node: Node, class_name_str: String) -> Node:
	if node is BikeController:
		return node
	for child in node.get_children():
		var result: Node = _find_node_by_class(child, class_name_str)
		if result:
			return result
	return null


func _connect_sliders() -> void:
	if _max_speed_slider:
		_max_speed_slider.value_changed.connect(_on_max_speed_changed)
	if _engine_force_slider:
		_engine_force_slider.value_changed.connect(_on_engine_force_changed)
	if _brake_slider:
		_brake_slider.value_changed.connect(_on_brake_changed)
	if _mass_slider:
		_mass_slider.value_changed.connect(_on_mass_changed)
	if _linear_damp_slider:
		_linear_damp_slider.value_changed.connect(_on_linear_damp_changed)
	if _steer_torque_slider:
		_steer_torque_slider.value_changed.connect(_on_steer_torque_changed)
	if _lean_torque_slider:
		_lean_torque_slider.value_changed.connect(_on_lean_torque_changed)
	# Arcade handling sliders
	if _vel_align_slider:
		_vel_align_slider.value_changed.connect(_on_vel_align_changed)
	if _drift_grip_slider:
		_drift_grip_slider.value_changed.connect(_on_drift_grip_changed)
	if _drift_kickout_slider:
		_drift_kickout_slider.value_changed.connect(_on_drift_kickout_changed)
	if _drift_steer_boost_slider:
		_drift_steer_boost_slider.value_changed.connect(_on_drift_steer_boost_changed)
	if _pitch_stab_slider:
		_pitch_stab_slider.value_changed.connect(_on_pitch_stab_changed)
	if _wall_grip_speed_slider:
		_wall_grip_speed_slider.value_changed.connect(_on_wall_grip_speed_changed)
	if _jump_slider:
		_jump_slider.value_changed.connect(_on_jump_changed)
	# Arcade sliders
	if _angular_damp_slider:
		_angular_damp_slider.value_changed.connect(_on_angular_damp_changed)
	if _air_pitch_slider:
		_air_pitch_slider.value_changed.connect(_on_air_pitch_changed)
	if _air_yaw_slider:
		_air_yaw_slider.value_changed.connect(_on_air_yaw_changed)
	if _fov_boost_slider:
		_fov_boost_slider.value_changed.connect(_on_fov_boost_changed)
	if _landing_squash_slider:
		_landing_squash_slider.value_changed.connect(_on_landing_squash_changed)
	if _disable_visual_checkbox:
		_disable_visual_checkbox.toggled.connect(_on_disable_visual_toggled)
	# Camera sliders
	if _base_fov_slider:
		_base_fov_slider.value_changed.connect(_on_base_fov_changed)
	if _camera_dist_slider:
		_camera_dist_slider.value_changed.connect(_on_camera_dist_changed)
	if _camera_height_slider:
		_camera_height_slider.value_changed.connect(_on_camera_height_changed)
	if _camera_angle_slider:
		_camera_angle_slider.value_changed.connect(_on_camera_angle_changed)
	# Suspension sliders
	if _susp_stiffness_slider:
		_susp_stiffness_slider.value_changed.connect(_on_susp_stiffness_changed)
	if _susp_damping_slider:
		_susp_damping_slider.value_changed.connect(_on_susp_damping_changed)
	if _susp_rest_slider:
		_susp_rest_slider.value_changed.connect(_on_susp_rest_changed)
	if _susp_travel_slider:
		_susp_travel_slider.value_changed.connect(_on_susp_travel_changed)
	# Tire grip sliders
	if _tire_grip_slider:
		_tire_grip_slider.value_changed.connect(_on_tire_grip_changed)
	if _climb_force_slider:
		_climb_force_slider.value_changed.connect(_on_climb_force_changed)
	if _bump_pop_slider:
		_bump_pop_slider.value_changed.connect(_on_bump_pop_changed)


func _sync_sliders_from_bike() -> void:
	if not _bike:
		return

	if _max_speed_slider:
		_max_speed_slider.value = _bike.max_speed
		_update_value_label(_max_speed_value, _bike.max_speed)
	if _engine_force_slider:
		_engine_force_slider.value = _bike.engine_force
		_update_value_label(_engine_force_value, _bike.engine_force, "N")
	if _brake_slider:
		_brake_slider.value = _bike.brake_force
		_update_value_label(_brake_value, _bike.brake_force, "N")
	if _mass_slider:
		_mass_slider.value = _bike.mass
		_update_value_label(_mass_value, _bike.mass, "kg")
	if _linear_damp_slider:
		_linear_damp_slider.value = _bike.linear_damp
		_update_value_label(_linear_damp_value, _bike.linear_damp)
	if _steer_torque_slider:
		_steer_torque_slider.value = _bike.steer_torque
		_update_value_label(_steer_torque_value, _bike.steer_torque)
	if _lean_torque_slider:
		_lean_torque_slider.value = _bike.lean_torque
		_update_value_label(_lean_torque_value, _bike.lean_torque)
	# Arcade handling sliders
	if _vel_align_slider:
		_vel_align_slider.value = _bike.velocity_alignment
		_update_value_label(_vel_align_value, _bike.velocity_alignment)
	if _drift_grip_slider:
		_drift_grip_slider.value = _bike.drift_grip
		_update_value_label(_drift_grip_value, _bike.drift_grip)
	if _drift_kickout_slider:
		_drift_kickout_slider.value = _bike.drift_kickout
		_update_value_label(_drift_kickout_value, _bike.drift_kickout)
	if _drift_steer_boost_slider:
		_drift_steer_boost_slider.value = _bike.drift_steer_boost
		_update_value_label(_drift_steer_boost_value, _bike.drift_steer_boost)
	if _pitch_stab_slider:
		_pitch_stab_slider.value = _bike.pitch_stabilization
		_update_value_label(_pitch_stab_value, _bike.pitch_stabilization)
	if _wall_grip_speed_slider:
		_wall_grip_speed_slider.value = _bike.wall_grip_speed_threshold
		_update_value_label(_wall_grip_speed_value, _bike.wall_grip_speed_threshold, " m/s")
	if _jump_slider:
		_jump_slider.value = _bike.jump_impulse
		_update_value_label(_jump_value, _bike.jump_impulse)
	# Arcade sliders
	if _angular_damp_slider:
		_angular_damp_slider.value = _bike.angular_damp
		_update_value_label(_angular_damp_value, _bike.angular_damp)
	if _air_pitch_slider:
		_air_pitch_slider.value = _bike.air_pitch_torque
		_update_value_label(_air_pitch_value, _bike.air_pitch_torque)
	if _air_yaw_slider:
		_air_yaw_slider.value = _bike.air_yaw_torque
		_update_value_label(_air_yaw_value, _bike.air_yaw_torque)
	if _fov_boost_slider:
		_fov_boost_slider.value = _bike.fov_boost
		_update_value_label(_fov_boost_value, _bike.fov_boost)
	if _landing_squash_slider:
		_landing_squash_slider.value = _bike.landing_squash_amount
		_update_value_label(_landing_squash_value, _bike.landing_squash_amount)
	if _disable_visual_checkbox:
		_disable_visual_checkbox.button_pressed = _bike.disable_visual_effects
	# Camera sliders
	if _base_fov_slider:
		_base_fov_slider.value = _bike.base_fov
		_update_value_label(_base_fov_value, _bike.base_fov)
	if _camera_dist_slider:
		_camera_dist_slider.value = _bike.camera_distance
		_update_value_label(_camera_dist_value, _bike.camera_distance)
	if _camera_height_slider:
		_camera_height_slider.value = _bike.camera_height
		_update_value_label(_camera_height_value, _bike.camera_height)
	if _camera_angle_slider:
		_camera_angle_slider.value = _bike.camera_angle
		_update_value_label(_camera_angle_value, _bike.camera_angle, "°")
	# Suspension sliders
	if _susp_stiffness_slider:
		_susp_stiffness_slider.value = _bike.suspension_stiffness
		_update_value_label(_susp_stiffness_value, _bike.suspension_stiffness)
	if _susp_damping_slider:
		_susp_damping_slider.value = _bike.suspension_damping
		_update_value_label(_susp_damping_value, _bike.suspension_damping)
	if _susp_rest_slider:
		_susp_rest_slider.value = _bike.suspension_rest_length
		_update_value_label(_susp_rest_value, _bike.suspension_rest_length)
	if _susp_travel_slider:
		_susp_travel_slider.value = _bike.max_suspension_travel
		_update_value_label(_susp_travel_value, _bike.max_suspension_travel)
	# Tire grip sliders
	if _tire_grip_slider:
		_tire_grip_slider.value = _bike.tire_grip
		_update_value_label(_tire_grip_value, _bike.tire_grip)
	if _climb_force_slider:
		_climb_force_slider.value = _bike.front_climb_force
		_update_value_label(_climb_force_value, _bike.front_climb_force)
	if _bump_pop_slider:
		_bump_pop_slider.value = _bike.bump_pop_strength
		_update_value_label(_bump_pop_value, _bike.bump_pop_strength)


func _update_value_label(label: Label, value: float, suffix: String = "") -> void:
	if label:
		label.text = "%.1f%s" % [value, suffix]


# === CALLBACKS ===

func _on_max_speed_changed(value: float) -> void:
	if _bike:
		_bike.max_speed = value
		_update_value_label(_max_speed_value, value)


func _on_engine_force_changed(value: float) -> void:
	if _bike:
		_bike.engine_force = value
		_update_value_label(_engine_force_value, value, "N")


func _on_brake_changed(value: float) -> void:
	if _bike:
		_bike.brake_force = value
		_update_value_label(_brake_value, value, "N")


func _on_mass_changed(value: float) -> void:
	if _bike:
		_bike.mass = value
		_update_value_label(_mass_value, value, "kg")


func _on_linear_damp_changed(value: float) -> void:
	if _bike:
		_bike.linear_damp = value
		_update_value_label(_linear_damp_value, value)


func _on_steer_torque_changed(value: float) -> void:
	if _bike:
		_bike.steer_torque = value
		_update_value_label(_steer_torque_value, value)


func _on_lean_torque_changed(value: float) -> void:
	if _bike:
		_bike.lean_torque = value
		_update_value_label(_lean_torque_value, value)


# === ARCADE HANDLING CALLBACKS ===

func _on_vel_align_changed(value: float) -> void:
	if _bike:
		_bike.velocity_alignment = value
		_update_value_label(_vel_align_value, value)


func _on_drift_grip_changed(value: float) -> void:
	if _bike:
		_bike.drift_grip = value
		_update_value_label(_drift_grip_value, value)


func _on_drift_kickout_changed(value: float) -> void:
	if _bike:
		_bike.drift_kickout = value
		_update_value_label(_drift_kickout_value, value)


func _on_drift_steer_boost_changed(value: float) -> void:
	if _bike:
		_bike.drift_steer_boost = value
		_update_value_label(_drift_steer_boost_value, value)


func _on_pitch_stab_changed(value: float) -> void:
	if _bike:
		_bike.pitch_stabilization = value
		_update_value_label(_pitch_stab_value, value)


func _on_wall_grip_speed_changed(value: float) -> void:
	if _bike:
		_bike.wall_grip_speed_threshold = value
		_update_value_label(_wall_grip_speed_value, value, " m/s")


func _on_jump_changed(value: float) -> void:
	if _bike:
		_bike.jump_impulse = value
		_update_value_label(_jump_value, value)


# === ARCADE CALLBACKS ===

func _on_angular_damp_changed(value: float) -> void:
	if _bike:
		_bike.angular_damp = value
		_update_value_label(_angular_damp_value, value)


func _on_air_pitch_changed(value: float) -> void:
	if _bike:
		_bike.air_pitch_torque = value
		_update_value_label(_air_pitch_value, value)


func _on_air_yaw_changed(value: float) -> void:
	if _bike:
		_bike.air_yaw_torque = value
		_update_value_label(_air_yaw_value, value)


func _on_fov_boost_changed(value: float) -> void:
	if _bike:
		_bike.fov_boost = value
		_update_value_label(_fov_boost_value, value)


func _on_landing_squash_changed(value: float) -> void:
	if _bike:
		_bike.landing_squash_amount = value
		_update_value_label(_landing_squash_value, value)


func _on_disable_visual_toggled(toggled_on: bool) -> void:
	if _bike:
		_bike.disable_visual_effects = toggled_on


# === CAMERA CALLBACKS ===

func _on_base_fov_changed(value: float) -> void:
	if _bike:
		_bike.base_fov = value
		_bike._camera.fov = value  # Apply immediately
		_update_value_label(_base_fov_value, value)


func _on_camera_dist_changed(value: float) -> void:
	if _bike:
		_bike.camera_distance = value
		_bike._camera.position.z = -value  # Apply immediately
		_update_value_label(_camera_dist_value, value)


func _on_camera_height_changed(value: float) -> void:
	if _bike:
		_bike.camera_height = value
		_bike._camera.position.y = value  # Apply immediately
		_update_value_label(_camera_height_value, value)


func _on_camera_angle_changed(value: float) -> void:
	if _bike:
		_bike.camera_angle = value
		_bike._camera.rotation.x = deg_to_rad(-value)  # Apply immediately
		_update_value_label(_camera_angle_value, value, "°")


# === SUSPENSION CALLBACKS ===

func _on_susp_stiffness_changed(value: float) -> void:
	if _bike:
		_bike.suspension_stiffness = value
		_update_value_label(_susp_stiffness_value, value)


func _on_susp_damping_changed(value: float) -> void:
	if _bike:
		_bike.suspension_damping = value
		_update_value_label(_susp_damping_value, value)


func _on_susp_rest_changed(value: float) -> void:
	if _bike:
		_bike.suspension_rest_length = value
		_update_value_label(_susp_rest_value, value)


func _on_susp_travel_changed(value: float) -> void:
	if _bike:
		_bike.max_suspension_travel = value
		_update_value_label(_susp_travel_value, value)


func _on_tire_grip_changed(value: float) -> void:
	if _bike:
		_bike.tire_grip = value
		_update_value_label(_tire_grip_value, value)


func _on_climb_force_changed(value: float) -> void:
	if _bike:
		_bike.front_climb_force = value
		_update_value_label(_climb_force_value, value)


func _on_bump_pop_changed(value: float) -> void:
	if _bike:
		_bike.bump_pop_strength = value
		_update_value_label(_bump_pop_value, value)


func _on_copy_pressed() -> void:
	if not _bike:
		return

	var text: String = "=== BIKE TUNING VALUES ===\n\n"
	text += "MOVEMENT:\n"
	text += "  Max Speed: %.1f\n" % _bike.max_speed
	text += "  Acceleration: %.1fN\n" % _bike.engine_force
	text += "  Brake Force: %.1fN\n" % _bike.brake_force
	text += "\nMOMENTUM:\n"
	text += "  Mass: %.1fkg\n" % _bike.mass
	text += "  Drag: %.2f\n" % _bike.linear_damp
	text += "\nSTEERING:\n"
	text += "  Steer Torque: %.1f\n" % _bike.steer_torque
	text += "  Lean Torque: %.1f\n" % _bike.lean_torque
	text += "\nARCADE HANDLING:\n"
	text += "  Velocity Alignment: %.2f\n" % _bike.velocity_alignment
	text += "  Drift Grip: %.1f\n" % _bike.drift_grip
	text += "  Drift Kickout: %.1f\n" % _bike.drift_kickout
	text += "  Drift Steer Boost: %.1f\n" % _bike.drift_steer_boost
	text += "  Pitch Stability: %.1f\n" % _bike.pitch_stabilization
	text += "  Wall Grip Speed: %.1f m/s\n" % _bike.wall_grip_speed_threshold
	text += "\nJUMP:\n"
	text += "  Jump Force: %.1f\n" % _bike.jump_impulse
	text += "\nARCADE FEEL:\n"
	text += "  Angular Damping: %.1f\n" % _bike.angular_damp
	text += "  Air Flip Power: %.1f\n" % _bike.air_pitch_torque
	text += "  Air Spin Power: %.1f\n" % _bike.air_yaw_torque
	text += "  Speed FOV Boost: %.1f\n" % _bike.fov_boost
	text += "  Landing Squash: %.2f\n" % _bike.landing_squash_amount
	text += "\nCAMERA:\n"
	text += "  Field of View: %.1f\n" % _bike.base_fov
	text += "  Camera Distance: %.1f\n" % _bike.camera_distance
	text += "  Camera Height: %.1f\n" % _bike.camera_height
	text += "  Camera Angle: %.1f°\n" % _bike.camera_angle
	text += "\nSUSPENSION:\n"
	text += "  Stiffness: %.1f\n" % _bike.suspension_stiffness
	text += "  Damping: %.1f\n" % _bike.suspension_damping
	text += "  Rest Length: %.2f\n" % _bike.suspension_rest_length
	text += "  Max Travel: %.2f\n" % _bike.max_suspension_travel
	text += "  Tire Grip: %.2f\n" % _bike.tire_grip
	text += "  Climb Force: %.1f\n" % _bike.front_climb_force

	DisplayServer.clipboard_set(text)
	_copy_button.text = "Copied!"
	await get_tree().create_timer(1.0).timeout
	_copy_button.text = "Copy Values"
