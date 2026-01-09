extends Node3D
## E2E tests for physics parameters:
## 1. Hill Free Roll - bike should roll freely on slopes with no input
## 2. Steep Sideways Tip - bike should tip over when slow and sideways on steep slope
## 3. Steep Sideways Stable - bike should stay stable when fast and sideways on steep slope
## 4. Suspension Bounce - bike should visibly compress suspension on landing

const BIKE_SCENE: PackedScene = preload("res://scenes/bike/bike.tscn")

# Test configuration
@export var test_duration: float = 3.0  # Seconds per test
@export var auto_advance: bool = true   # Auto-advance to next test

var _bike: BikeController
var _test_start_time: float = 0.0
var _test_in_progress: bool = false
var _initial_position: Vector3
var _initial_rotation: Vector3
var _max_suspension_compression: float = 0.0

enum TestType { 
	HILL_FREE_ROLL,       # Bike on 30deg slope should roll freely
	STEEP_SIDEWAYS_TIP,   # Bike sideways on steep slope at low speed should tip
	STEEP_SIDEWAYS_STABLE,# Bike sideways on steep slope at high speed should stay up
	SUSPENSION_BOUNCE,    # Bike dropped should show visible suspension compression
}

var _current_test: TestType = TestType.HILL_FREE_ROLL
var _test_results: Dictionary = {}

@onready var _slope: StaticBody3D = $Slope
@onready var _steep_slope: StaticBody3D = $SteepSlope
@onready var _status_label: Label3D = $StatusLabel
@onready var _results_label: Label3D = $ResultsLabel
@onready var _debug_label: Label3D = $DebugLabel


func _ready() -> void:
	_status_label.text = "Initializing tests..."
	_results_label.text = ""
	
	await get_tree().create_timer(0.5).timeout
	_spawn_bike()


func _spawn_bike() -> void:
	_bike = BIKE_SCENE.instantiate() as BikeController
	add_child(_bike)
	
	print("\n=== PHYSICS PARAMETER TESTS ===\n")
	_start_test(TestType.HILL_FREE_ROLL)


func _start_test(test_type: TestType) -> void:
	_current_test = test_type
	_test_in_progress = false
	_max_suspension_compression = 0.0
	
	# Release all inputs
	Input.action_release("accelerate")
	Input.action_release("brake")
	Input.action_release("steer_left")
	Input.action_release("steer_right")
	
	# Configure test
	match test_type:
		TestType.HILL_FREE_ROLL:
			_setup_hill_roll_test()
		TestType.STEEP_SIDEWAYS_TIP:
			_setup_steep_tip_test()
		TestType.STEEP_SIDEWAYS_STABLE:
			_setup_steep_stable_test()
		TestType.SUSPENSION_BOUNCE:
			_setup_suspension_test()


func _setup_hill_roll_test() -> void:
	var test_name: String = "HILL FREE ROLL"
	print("\n--- %s ---" % test_name)
	_status_label.text = test_name
	
	# Show 30deg slope, hide steep slope
	_slope.visible = true
	_slope.process_mode = Node.PROCESS_MODE_INHERIT
	if _steep_slope:
		_steep_slope.visible = false
		_steep_slope.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Place bike on the slope facing downhill
	var spawn_pos: Vector3 = Vector3(0, 6, -2)
	_bike.reset_position(spawn_pos)
	_bike.global_rotation = Vector3.ZERO
	
	# Wait for landing
	await get_tree().create_timer(1.5).timeout
	
	_initial_position = _bike.global_position
	print("Bike at Y=%.2f, Speed=%.2f" % [_bike.global_position.y, _bike.linear_velocity.length()])
	
	_test_start_time = Time.get_ticks_msec() / 1000.0
	_test_in_progress = true


func _setup_steep_tip_test() -> void:
	var test_name: String = "STEEP SIDEWAYS TIP"
	print("\n--- %s ---" % test_name)
	_status_label.text = test_name
	
	# Show steep slope (60deg)
	_slope.visible = false
	_slope.process_mode = Node.PROCESS_MODE_DISABLED
	if _steep_slope:
		_steep_slope.visible = true
		_steep_slope.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Place bike SIDEWAYS on steep slope at low speed
	var spawn_pos: Vector3 = Vector3(0, 5, 0)
	_bike.reset_position(spawn_pos)
	# Rotate bike 90 degrees so it's sideways on the slope
	_bike.global_rotation = Vector3(0, PI/2, 0)
	_bike.linear_velocity = Vector3.ZERO  # Start stationary
	
	await get_tree().create_timer(1.0).timeout
	
	_initial_rotation = _bike.global_rotation
	print("Bike sideways on steep slope, speed=%.2f" % _bike.linear_velocity.length())
	
	_test_start_time = Time.get_ticks_msec() / 1000.0
	_test_in_progress = true


func _setup_steep_stable_test() -> void:
	var test_name: String = "STEEP SIDEWAYS STABLE"
	print("\n--- %s ---" % test_name)
	_status_label.text = test_name
	
	# Show steep slope (60deg)
	_slope.visible = false
	_slope.process_mode = Node.PROCESS_MODE_DISABLED
	if _steep_slope:
		_steep_slope.visible = true
		_steep_slope.process_mode = Node.PROCESS_MODE_INHERIT
	
	# Place bike SIDEWAYS on steep slope WITH high speed
	var spawn_pos: Vector3 = Vector3(0, 5, 0)
	_bike.reset_position(spawn_pos)
	_bike.global_rotation = Vector3(0, PI/2, 0)
	# Give it high sideways velocity (above wall_tip_speed)
	_bike.linear_velocity = Vector3(8, 0, 0)  # Moving fast sideways
	
	await get_tree().create_timer(0.5).timeout
	
	_initial_rotation = _bike.global_rotation
	print("Bike sideways on steep slope with speed=%.2f" % _bike.linear_velocity.length())
	
	_test_start_time = Time.get_ticks_msec() / 1000.0
	_test_in_progress = true


func _setup_suspension_test() -> void:
	var test_name: String = "SUSPENSION BOUNCE"
	print("\n--- %s ---" % test_name)
	_status_label.text = test_name
	
	# Show flat ground, hide slopes
	_slope.visible = false
	_slope.process_mode = Node.PROCESS_MODE_DISABLED
	if _steep_slope:
		_steep_slope.visible = false
		_steep_slope.process_mode = Node.PROCESS_MODE_DISABLED
	
	# Drop bike from height
	var spawn_pos: Vector3 = Vector3(0, 3, 0)
	_bike.reset_position(spawn_pos)
	_bike.global_rotation = Vector3.ZERO
	
	print("Dropping bike from height...")
	
	_test_start_time = Time.get_ticks_msec() / 1000.0
	_test_in_progress = true


func _physics_process(delta: float) -> void:
	if not _test_in_progress or not is_instance_valid(_bike):
		return
	
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _test_start_time
	
	# Track max suspension compression for suspension test
	if _current_test == TestType.SUSPENSION_BOUNCE:
		var compression: float = maxf(_bike._front_suspension_compression, _bike._rear_suspension_compression)
		_max_suspension_compression = maxf(_max_suspension_compression, compression)
	
	# Update debug info
	var roll_angle: float = rad_to_deg(_bike.global_rotation.z)
	var speed: float = _bike.linear_velocity.length()
	var y_delta: float = _bike.global_position.y - _initial_position.y if _current_test == TestType.HILL_FREE_ROLL else 0.0
	var is_upright: bool = _bike.global_transform.basis.y.y > 0.3
	
	_debug_label.text = "Speed: %.1f m/s\nRoll: %.1f°\nY delta: %.2fm\nUpright: %s\nTime: %.1fs\nSusp: %.3f" % [
		speed, roll_angle, y_delta, "Yes" if is_upright else "NO", elapsed, _max_suspension_compression
	]
	
	# Evaluate current test
	match _current_test:
		TestType.HILL_FREE_ROLL:
			_evaluate_hill_roll_test(elapsed, speed)
		TestType.STEEP_SIDEWAYS_TIP:
			_evaluate_steep_tip_test(elapsed, roll_angle)
		TestType.STEEP_SIDEWAYS_STABLE:
			_evaluate_steep_stable_test(elapsed, roll_angle)
		TestType.SUSPENSION_BOUNCE:
			_evaluate_suspension_test(elapsed)


func _evaluate_hill_roll_test(elapsed: float, speed: float) -> void:
	# Success: bike reaches >2 m/s within test duration
	var reached_speed: bool = speed > 2.0
	
	if reached_speed:
		_complete_test(_current_test, true, "PASS - reached %.1f m/s (gravity roll working)" % speed)
	elif elapsed >= test_duration:
		_complete_test(_current_test, false, "FAIL - only reached %.1f m/s (free roll not working)" % speed)


func _evaluate_steep_tip_test(elapsed: float, roll_angle: float) -> void:
	# Success: bike roll angle exceeds 60 degrees (tipped over)
	var tipped: bool = absf(roll_angle) > 60.0
	
	if tipped:
		_complete_test(_current_test, true, "PASS - tipped to %.1f° (tip-over working)" % roll_angle)
	elif elapsed >= test_duration:
		_complete_test(_current_test, false, "FAIL - only tilted to %.1f° (bike too stable)" % roll_angle)


func _evaluate_steep_stable_test(elapsed: float, roll_angle: float) -> void:
	# Success: bike stays upright (roll < 30 degrees) throughout test
	var fell: bool = absf(roll_angle) > 60.0
	
	if fell:
		_complete_test(_current_test, false, "FAIL - fell at speed (roll=%.1f°)" % roll_angle)
	elif elapsed >= test_duration:
		if absf(roll_angle) < 30.0:
			_complete_test(_current_test, true, "PASS - stayed upright at speed (roll=%.1f°)" % roll_angle)
		else:
			_complete_test(_current_test, false, "FAIL - tilted too much (roll=%.1f°)" % roll_angle)


func _evaluate_suspension_test(elapsed: float) -> void:
	# Wait for landing and check compression
	if elapsed >= test_duration:
		var visible_compression: bool = _max_suspension_compression > 0.05
		if visible_compression:
			_complete_test(_current_test, true, "PASS - visible compression (%.3fm)" % _max_suspension_compression)
		else:
			_complete_test(_current_test, false, "FAIL - no visible compression (%.3fm)" % _max_suspension_compression)


func _complete_test(test_type: TestType, passed: bool, result: String) -> void:
	_test_in_progress = false
	
	var test_name: String = TestType.keys()[test_type]
	var status: String = "PASS" if passed else "FAIL"
	
	_test_results[test_type] = {"passed": passed, "result": result}
	
	print("[%s] %s: %s" % [status, test_name, result])
	
	# Update results display
	_update_results_display()
	
	# Advance to next test
	if auto_advance:
		await get_tree().create_timer(1.0).timeout
		_advance_to_next_test()


func _advance_to_next_test() -> void:
	var next_test: int = _current_test + 1
	if next_test < TestType.size():
		_start_test(next_test as TestType)
	else:
		_finish_all_tests()


func _update_results_display() -> void:
	var text: String = "=== RESULTS ===\n"
	
	for test_type in _test_results:
		var result: Dictionary = _test_results[test_type]
		var status: String = "PASS" if result.passed else "FAIL"
		var name: String = TestType.keys()[test_type]
		text += "[%s] %s\n" % [status, name]
	
	_results_label.text = text


func _finish_all_tests() -> void:
	print("\n=== ALL TESTS COMPLETE ===\n")
	
	var passed_count: int = 0
	var total_count: int = _test_results.size()
	
	var summary: String = "\n=== PHYSICS PARAM TEST SUMMARY ===\n\n"
	
	for test_type in _test_results:
		var result: Dictionary = _test_results[test_type]
		var status: String = "PASS" if result.passed else "FAIL"
		var name: String = TestType.keys()[test_type]
		if result.passed:
			passed_count += 1
		summary += "[%s] %s\n      %s\n\n" % [status, name, result.result]
	
	summary += "Total: %d/%d passed\n" % [passed_count, total_count]
	
	print(summary)
	
	_status_label.text = "COMPLETE: %d/%d" % [passed_count, total_count]
	
	if passed_count == total_count:
		_status_label.modulate = Color.GREEN
	elif passed_count >= total_count / 2:
		_status_label.modulate = Color.YELLOW
	else:
		_status_label.modulate = Color.RED


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_R:
				print("\n=== RESTART ===\n")
				_test_results.clear()
				_test_in_progress = false
				_start_test(TestType.HILL_FREE_ROLL)
			KEY_ESCAPE:
				get_tree().quit()
			KEY_SPACE:
				# Skip to next test
				if _test_in_progress:
					_test_in_progress = false
					_advance_to_next_test()
