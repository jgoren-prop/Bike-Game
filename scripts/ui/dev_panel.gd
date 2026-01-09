extends CanvasLayer

## RigidBody3D Bike Dev Panel - real-time physics parameter tweaking

var _bike: BikeController = null
var _debug_overlay_visible: bool = false

@onready var _panel: Control = $Panel
@onready var _speed_label: Label = $Panel/SpeedDisplay/SpeedLabel
@onready var _debug_overlay: Label = $DebugOverlay

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

# TRACTION MODEL sliders (simplified for true free-roll)
@onready var _traction_accel_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/TractionAccelSlider
@onready var _lateral_grip_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/LateralGripSlider
@onready var _drift_lateral_grip_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/DriftLateralGripSlider
@onready var _idle_brake_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/IdleBrakeSlider
@onready var _max_traction_slider: HSlider = $Panel/ScrollContainer/VBox/GripSection/MaxTractionSlider

# STABILIZATION sliders (normal mode)
@onready var _normal_stability_slider: HSlider = $Panel/ScrollContainer/VBox/StabSection/NormalStabilitySlider
@onready var _normal_roll_damp_slider: HSlider = $Panel/ScrollContainer/VBox/StabSection/NormalRollDampSlider
@onready var _lean_angle_slider: HSlider = $Panel/ScrollContainer/VBox/StabSection/LeanAngleSlider

# TIPPING BEHAVIOR sliders (angle-based for intuitive tuning)
@onready var _tip_start_angle_slider: HSlider = $Panel/ScrollContainer/VBox/SteepSection/TipStartAngleSlider
@onready var _tip_full_angle_slider: HSlider = $Panel/ScrollContainer/VBox/SteepSection/TipFullAngleSlider
@onready var _roll_risk_threshold_slider: HSlider = $Panel/ScrollContainer/VBox/SteepSection/RollRiskThresholdSlider
@onready var _tip_safe_speed_slider: HSlider = $Panel/ScrollContainer/VBox/SteepSection/TipSafeSpeedSlider
@onready var _tip_torque_strength_slider: HSlider = $Panel/ScrollContainer/VBox/SteepSection/TipTorqueStrengthSlider
@onready var _steep_upright_slider: HSlider = $Panel/ScrollContainer/VBox/SteepSection/SteepUprightSlider
@onready var _steep_roll_damp_slider: HSlider = $Panel/ScrollContainer/VBox/SteepSection/SteepRollDampSlider

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

# Legacy toggle checkboxes
@onready var _legacy_bump_checkbox: CheckBox = $Panel/ScrollContainer/VBox/SuspensionSection/LegacyBumpCheckbox
@onready var _legacy_climb_checkbox: CheckBox = $Panel/ScrollContainer/VBox/SuspensionSection/LegacyClimbCheckbox

# Value labels
@onready var _max_speed_value: Label = $Panel/ScrollContainer/VBox/MovementSection/MaxSpeedValue
@onready var _engine_force_value: Label = $Panel/ScrollContainer/VBox/MovementSection/AccelerationValue
@onready var _brake_value: Label = $Panel/ScrollContainer/VBox/MovementSection/BrakeValue
@onready var _mass_value: Label = $Panel/ScrollContainer/VBox/MomentumSection/MassValue
@onready var _linear_damp_value: Label = $Panel/ScrollContainer/VBox/MomentumSection/DragValue
@onready var _steer_torque_value: Label = $Panel/ScrollContainer/VBox/SteeringSection/TurnSpeedValue
@onready var _lean_torque_value: Label = $Panel/ScrollContainer/VBox/SteeringSection/TurnInertiaValue

# TRACTION MODEL value labels
@onready var _traction_accel_value: Label = $Panel/ScrollContainer/VBox/GripSection/TractionAccelValue
@onready var _lateral_grip_value: Label = $Panel/ScrollContainer/VBox/GripSection/LateralGripValue
@onready var _drift_lateral_grip_value: Label = $Panel/ScrollContainer/VBox/GripSection/DriftLateralGripValue
@onready var _idle_brake_value: Label = $Panel/ScrollContainer/VBox/GripSection/IdleBrakeValue
@onready var _max_traction_value: Label = $Panel/ScrollContainer/VBox/GripSection/MaxTractionValue

# STABILIZATION value labels
@onready var _normal_stability_value: Label = $Panel/ScrollContainer/VBox/StabSection/NormalStabilityValue
@onready var _normal_roll_damp_value: Label = $Panel/ScrollContainer/VBox/StabSection/NormalRollDampValue
@onready var _lean_angle_value: Label = $Panel/ScrollContainer/VBox/StabSection/LeanAngleValue

# TIPPING BEHAVIOR value labels
@onready var _tip_start_angle_value: Label = $Panel/ScrollContainer/VBox/SteepSection/TipStartAngleValue
@onready var _tip_full_angle_value: Label = $Panel/ScrollContainer/VBox/SteepSection/TipFullAngleValue
@onready var _roll_risk_threshold_value: Label = $Panel/ScrollContainer/VBox/SteepSection/RollRiskThresholdValue
@onready var _tip_safe_speed_value: Label = $Panel/ScrollContainer/VBox/SteepSection/TipSafeSpeedValue
@onready var _tip_torque_strength_value: Label = $Panel/ScrollContainer/VBox/SteepSection/TipTorqueStrengthValue
@onready var _steep_upright_value: Label = $Panel/ScrollContainer/VBox/SteepSection/SteepUprightValue
@onready var _steep_roll_damp_value: Label = $Panel/ScrollContainer/VBox/SteepSection/SteepRollDampValue

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

# (removed tire_grip, climb_force, bump_pop - now behind legacy toggles)


@onready var _copy_button: Button = $Panel/ScrollContainer/VBox/CopyButton

func _ready() -> void:
	_panel.visible = false
	_connect_sliders()
	if _copy_button:
		_copy_button.pressed.connect(_on_copy_pressed)


func _process(_delta: float) -> void:
	# Find bike if not already found
	if not _bike:
		_find_bike()
	
	if not _bike:
		return
	
	# Build debug text
	var grounded_status: String = ""
	if _bike.is_front_grounded() and _bike.is_rear_grounded():
		grounded_status = " [GROUNDED]"
	elif _bike.is_front_grounded():
		grounded_status = " [FRONT]"
	elif _bike.is_rear_grounded():
		grounded_status = " [REAR]"
	else:
		grounded_status = " [AIR]"
	
	# Show tipping debug info
	var mode_name: String = _bike.get_stability_mode_name()
	var slope_angle: float = _bike.get_slope_angle()
	var roll_risk: float = _bike.get_roll_risk()
	var tip_blend: float = _bike.get_tip_blend()
	
	# Platform debug info
	var susp_info: Dictionary = _bike.get_debug_suspension_info()
	var platform_str: String = ""
	if susp_info.on_platform:
		platform_str = "\nPLATFORM: vel_y=%.2f | comp_f=%.3f | comp_r=%.3f" % [
			susp_info.platform_vel_y, susp_info.front_compression, susp_info.rear_compression
		]
	
	var debug_text: String = "Speed: %.1f m/s%s\nMode: %s | Slope: %.1f° | Risk: %.2f | Blend: %.2f%s" % [
		_bike.get_current_speed(), grounded_status,
		mode_name, slope_angle, roll_risk, tip_blend, platform_str
	]
	
	# Update dev panel label (when panel is open)
	if _speed_label:
		_speed_label.text = debug_text
	
	# Update debug overlay (F2 toggle, doesn't pause game)
	if _debug_overlay:
		_debug_overlay.visible = _debug_overlay_visible
		if _debug_overlay_visible:
			_debug_overlay.text = debug_text


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_F1:
			toggle_panel()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_F2:
			toggle_debug_overlay()
			get_viewport().set_input_as_handled()


func toggle_debug_overlay() -> void:
	_debug_overlay_visible = not _debug_overlay_visible
	if _debug_overlay_visible and not _bike:
		_find_bike()


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
	# TRACTION MODEL sliders
	if _traction_accel_slider:
		_traction_accel_slider.value_changed.connect(_on_traction_accel_changed)
	if _lateral_grip_slider:
		_lateral_grip_slider.value_changed.connect(_on_lateral_grip_changed)
	if _drift_lateral_grip_slider:
		_drift_lateral_grip_slider.value_changed.connect(_on_drift_lateral_grip_changed)
	if _idle_brake_slider:
		_idle_brake_slider.value_changed.connect(_on_idle_brake_changed)
	if _max_traction_slider:
		_max_traction_slider.value_changed.connect(_on_max_traction_changed)
	# STABILIZATION sliders (normal mode)
	if _normal_stability_slider:
		_normal_stability_slider.value_changed.connect(_on_normal_stability_changed)
	if _normal_roll_damp_slider:
		_normal_roll_damp_slider.value_changed.connect(_on_normal_roll_damp_changed)
	if _lean_angle_slider:
		_lean_angle_slider.value_changed.connect(_on_lean_angle_changed)
	# TIPPING BEHAVIOR sliders
	if _tip_start_angle_slider:
		_tip_start_angle_slider.value_changed.connect(_on_tip_start_angle_changed)
	if _tip_full_angle_slider:
		_tip_full_angle_slider.value_changed.connect(_on_tip_full_angle_changed)
	if _roll_risk_threshold_slider:
		_roll_risk_threshold_slider.value_changed.connect(_on_roll_risk_threshold_changed)
	if _tip_safe_speed_slider:
		_tip_safe_speed_slider.value_changed.connect(_on_tip_safe_speed_changed)
	if _tip_torque_strength_slider:
		_tip_torque_strength_slider.value_changed.connect(_on_tip_torque_strength_changed)
	if _steep_upright_slider:
		_steep_upright_slider.value_changed.connect(_on_steep_upright_changed)
	if _steep_roll_damp_slider:
		_steep_roll_damp_slider.value_changed.connect(_on_steep_roll_damp_changed)
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
	# Legacy toggle connections
	if _legacy_bump_checkbox:
		_legacy_bump_checkbox.toggled.connect(_on_legacy_bump_toggled)
	if _legacy_climb_checkbox:
		_legacy_climb_checkbox.toggled.connect(_on_legacy_climb_toggled)


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
	# TRACTION MODEL sliders
	if _traction_accel_slider:
		_traction_accel_slider.value = _bike.traction_accel_time
		_update_value_label(_traction_accel_value, _bike.traction_accel_time, "s")
	if _lateral_grip_slider:
		_lateral_grip_slider.value = _bike.lateral_grip_strength
		_update_value_label(_lateral_grip_value, _bike.lateral_grip_strength)
	if _drift_lateral_grip_slider:
		_drift_lateral_grip_slider.value = _bike.drift_lateral_grip
		_update_value_label(_drift_lateral_grip_value, _bike.drift_lateral_grip)
	if _idle_brake_slider:
		_idle_brake_slider.value = _bike.idle_brake_time
		_update_value_label(_idle_brake_value, _bike.idle_brake_time, "s")
	if _max_traction_slider:
		_max_traction_slider.value = _bike.max_traction_force
		_update_value_label(_max_traction_value, _bike.max_traction_force, "N")
	# STABILIZATION sliders (normal mode)
	if _normal_stability_slider:
		_normal_stability_slider.value = _bike.normal_upright_strength
		_update_value_label(_normal_stability_value, _bike.normal_upright_strength)
	if _normal_roll_damp_slider:
		_normal_roll_damp_slider.value = _bike.normal_roll_damping
		_update_value_label(_normal_roll_damp_value, _bike.normal_roll_damping)
	if _lean_angle_slider:
		_lean_angle_slider.value = _bike.lean_into_turn_angle
		_update_value_label(_lean_angle_value, _bike.lean_into_turn_angle, " rad")
	# TIPPING BEHAVIOR sliders
	if _tip_start_angle_slider:
		_tip_start_angle_slider.value = _bike.tip_start_angle
		_update_value_label(_tip_start_angle_value, _bike.tip_start_angle, "°")
	if _tip_full_angle_slider:
		_tip_full_angle_slider.value = _bike.tip_full_angle
		_update_value_label(_tip_full_angle_value, _bike.tip_full_angle, "°")
	if _roll_risk_threshold_slider:
		_roll_risk_threshold_slider.value = _bike.roll_risk_threshold
		_update_value_label(_roll_risk_threshold_value, _bike.roll_risk_threshold)
	if _tip_safe_speed_slider:
		_tip_safe_speed_slider.value = _bike.tip_safe_speed
		_update_value_label(_tip_safe_speed_value, _bike.tip_safe_speed, " m/s")
	if _tip_torque_strength_slider:
		_tip_torque_strength_slider.value = _bike.tip_torque_strength
		_update_value_label(_tip_torque_strength_value, _bike.tip_torque_strength, " Nm")
	if _steep_upright_slider:
		_steep_upright_slider.value = _bike.steep_upright_strength
		_update_value_label(_steep_upright_value, _bike.steep_upright_strength)
	if _steep_roll_damp_slider:
		_steep_roll_damp_slider.value = _bike.steep_roll_damping
		_update_value_label(_steep_roll_damp_value, _bike.steep_roll_damping)
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
	# Legacy toggles
	if _legacy_bump_checkbox:
		_legacy_bump_checkbox.button_pressed = _bike.enable_legacy_bump_assist
	if _legacy_climb_checkbox:
		_legacy_climb_checkbox.button_pressed = _bike.enable_legacy_climb_assist


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


# === TRACTION MODEL CALLBACKS ===

func _on_traction_accel_changed(value: float) -> void:
	if _bike:
		_bike.traction_accel_time = value
		_update_value_label(_traction_accel_value, value, "s")


func _on_lateral_grip_changed(value: float) -> void:
	if _bike:
		_bike.lateral_grip_strength = value
		_update_value_label(_lateral_grip_value, value)


func _on_drift_lateral_grip_changed(value: float) -> void:
	if _bike:
		_bike.drift_lateral_grip = value
		_update_value_label(_drift_lateral_grip_value, value)


func _on_idle_brake_changed(value: float) -> void:
	if _bike:
		_bike.idle_brake_time = value
		_update_value_label(_idle_brake_value, value, "s")


func _on_max_traction_changed(value: float) -> void:
	if _bike:
		_bike.max_traction_force = value
		_update_value_label(_max_traction_value, value, "N")


# === STABILIZATION CALLBACKS (Normal Mode) ===

func _on_normal_stability_changed(value: float) -> void:
	if _bike:
		_bike.normal_upright_strength = value
		_update_value_label(_normal_stability_value, value)


func _on_normal_roll_damp_changed(value: float) -> void:
	if _bike:
		_bike.normal_roll_damping = value
		_update_value_label(_normal_roll_damp_value, value)


func _on_lean_angle_changed(value: float) -> void:
	if _bike:
		_bike.lean_into_turn_angle = value
		_update_value_label(_lean_angle_value, value, " rad")


# === TIPPING BEHAVIOR CALLBACKS ===

func _on_tip_start_angle_changed(value: float) -> void:
	if _bike:
		_bike.tip_start_angle = value
		_update_value_label(_tip_start_angle_value, value, "°")


func _on_tip_full_angle_changed(value: float) -> void:
	if _bike:
		_bike.tip_full_angle = value
		_update_value_label(_tip_full_angle_value, value, "°")


func _on_roll_risk_threshold_changed(value: float) -> void:
	if _bike:
		_bike.roll_risk_threshold = value
		_update_value_label(_roll_risk_threshold_value, value)


func _on_tip_safe_speed_changed(value: float) -> void:
	if _bike:
		_bike.tip_safe_speed = value
		_update_value_label(_tip_safe_speed_value, value, " m/s")


func _on_tip_torque_strength_changed(value: float) -> void:
	if _bike:
		_bike.tip_torque_strength = value
		_update_value_label(_tip_torque_strength_value, value, " Nm")


func _on_steep_upright_changed(value: float) -> void:
	if _bike:
		_bike.steep_upright_strength = value
		_update_value_label(_steep_upright_value, value)


func _on_steep_roll_damp_changed(value: float) -> void:
	if _bike:
		_bike.steep_roll_damping = value
		_update_value_label(_steep_roll_damp_value, value)


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


func _on_legacy_bump_toggled(toggled_on: bool) -> void:
	if _bike:
		_bike.enable_legacy_bump_assist = toggled_on


func _on_legacy_climb_toggled(toggled_on: bool) -> void:
	if _bike:
		_bike.enable_legacy_climb_assist = toggled_on


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
	text += "\nTRACTION MODEL:\n"
	text += "  Traction Accel Time: %.2fs\n" % _bike.traction_accel_time
	text += "  Lateral Grip: %.1f\n" % _bike.lateral_grip_strength
	text += "  Drift Lateral Grip: %.1f\n" % _bike.drift_lateral_grip
	text += "  Idle Brake Time: %.2fs\n" % _bike.idle_brake_time
	text += "  Max Traction Force: %.1fN\n" % _bike.max_traction_force
	text += "\nSTABILIZATION (Normal):\n"
	text += "  Normal Stability: %.1f\n" % _bike.normal_upright_strength
	text += "  Normal Roll Damping: %.1f\n" % _bike.normal_roll_damping
	text += "  Lean Angle: %.2f rad\n" % _bike.lean_into_turn_angle
	text += "\nTIPPING BEHAVIOR:\n"
	text += "  Tip Start Angle: %.1f°\n" % _bike.tip_start_angle
	text += "  Tip Full Angle: %.1f°\n" % _bike.tip_full_angle
	text += "  Roll Risk Threshold: %.2f\n" % _bike.roll_risk_threshold
	text += "  Tip Safe Speed: %.1f m/s\n" % _bike.tip_safe_speed
	text += "  Tip Torque Strength: %.1f Nm\n" % _bike.tip_torque_strength
	text += "  Steep Upright Strength: %.1f\n" % _bike.steep_upright_strength
	text += "  Steep Roll Damping: %.1f\n" % _bike.steep_roll_damping
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
	text += "\nLEGACY SYSTEMS:\n"
	text += "  Bump Assist: %s\n" % ("ON" if _bike.enable_legacy_bump_assist else "OFF")
	text += "  Climb Assist: %s\n" % ("ON" if _bike.enable_legacy_climb_assist else "OFF")

	DisplayServer.clipboard_set(text)
	_copy_button.text = "Copied!"
	await get_tree().create_timer(1.0).timeout
	_copy_button.text = "Copy Values"
