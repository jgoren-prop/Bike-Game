extends Node3D
## Automated test for tire grip climbing mechanics
## Tests if the bike can climb over various bump sizes

const BIKE_SCENE: PackedScene = preload("res://scenes/bike/bike.tscn")

# Test configuration
@export var test_max_speeds: Array[float] = [3.0, 5.0, 8.0]
@export var bump_heights: Array[float] = [0.05, 0.1, 0.15, 0.2]
@export var timeout_per_test: float = 10.0

var _bike: BikeController
var _current_test_index: int = 0
var _test_start_time: float = 0.0
var _all_tests: Array[Dictionary] = []
var _test_in_progress: bool = false
var _current_max_speed: float = 0.0

enum TestState { IDLE, STABILIZING, RUNNING, COMPLETE }
var _state: TestState = TestState.IDLE

@onready var _ground: StaticBody3D = $Ground
@onready var _bump: StaticBody3D = $TestBump
@onready var _results_label: Label3D = $ResultsLabel
@onready var _status_label: Label3D = $StatusLabel


func _ready() -> void:
	for max_speed in test_max_speeds:
		for height in bump_heights:
			_all_tests.append({
				"max_speed": max_speed,
				"height": height,
				"passed": false,
				"reason": ""
			})
	
	print("Built %d tests" % _all_tests.size())
	_status_label.text = "Starting %d tests..." % _all_tests.size()
	
	await get_tree().create_timer(0.5).timeout
	_spawn_bike()


func _spawn_bike() -> void:
	_bike = BIKE_SCENE.instantiate() as BikeController
	add_child(_bike)
	
	# Spawn high enough to drop onto ground cleanly
	_bike.global_position = Vector3(0, 1.5, -8)
	_bike.global_rotation = Vector3.ZERO
	_bike.linear_velocity = Vector3.ZERO
	_bike.angular_velocity = Vector3.ZERO
	
	print("Bike spawned - waiting to land...")
	_status_label.text = "Bike landing..."
	
	# Wait for bike to land and stabilize
	await get_tree().create_timer(1.5).timeout
	
	print("Bike stable at Y=%.2f" % _bike.global_position.y)
	_start_next_test()


func _start_next_test() -> void:
	if _current_test_index >= _all_tests.size():
		_finish_all_tests()
		return
	
	var test: Dictionary = _all_tests[_current_test_index]
	print("\n--- Test %d/%d: max %.1f m/s @ %.0f cm bump ---" % [
		_current_test_index + 1, _all_tests.size(), test.max_speed, test.height * 100
	])
	_setup_test(test.max_speed, test.height)


func _setup_test(max_speed: float, bump_height: float) -> void:
	_state = TestState.STABILIZING
	_test_in_progress = false
	_current_max_speed = max_speed
	
	Input.action_release("accelerate")
	
	# Configure bump
	var bump_mesh: MeshInstance3D = _bump.get_node("Mesh")
	var bump_collision: CollisionShape3D = _bump.get_node("Collision")
	
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = Vector3(4, bump_height, 0.3)
	bump_mesh.mesh = box_mesh
	
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(4, bump_height, 0.3)
	bump_collision.shape = box_shape
	
	_bump.global_position = Vector3(0, bump_height / 2.0, 0)
	
	# Use bike's reset function which zeros everything properly
	_bike.reset_position(Vector3(0, 1.5, -8))
	_bike.max_speed = max_speed
	
	_status_label.text = "Test %d/%d: stabilizing..." % [_current_test_index + 1, _all_tests.size()]
	
	# Wait for bike to land and settle
	await get_tree().create_timer(1.0).timeout
	
	# Check if bike is still upright
	if _bike.global_transform.basis.y.y < 0.5:
		print("Bike unstable, retrying...")
		_bike.reset_position(Vector3(0, 1.5, -8))
		await get_tree().create_timer(1.0).timeout
	
	# Start test
	_test_start_time = Time.get_ticks_msec() / 1000.0
	_test_in_progress = true
	_state = TestState.RUNNING
	
	_status_label.text = "Test %d/%d: %.0f m/s @ %.0fcm - GO!" % [
		_current_test_index + 1, _all_tests.size(), max_speed, bump_height * 100
	]
	
	Input.action_press("accelerate")
	print("GO - holding W")


func _physics_process(_delta: float) -> void:
	if _state != TestState.RUNNING or not _test_in_progress:
		return
	
	if _current_test_index >= _all_tests.size():
		return
	
	var elapsed: float = (Time.get_ticks_msec() / 1000.0) - _test_start_time
	
	# Success
	if _bike.global_position.z > 3.0:
		_complete_test(true, "Cleared in %.1fs" % elapsed)
		return
	
	# Timeout
	if elapsed > timeout_per_test:
		_complete_test(false, "Timeout at Z=%.1f" % _bike.global_position.z)
		return
	
	# Fell off
	if _bike.global_position.y < -1.0:
		_complete_test(false, "Fell off")
		return
	
	# Flipped - but only check after 1 second (give time to stabilize)
	if elapsed > 1.0 and _bike.global_transform.basis.y.y < 0:
		_complete_test(false, "Flipped")
		return


func _complete_test(passed: bool, reason: String) -> void:
	if not _test_in_progress:
		return
	
	_test_in_progress = false
	_state = TestState.IDLE
	Input.action_release("accelerate")
	
	var test: Dictionary = _all_tests[_current_test_index]
	test.passed = passed
	test.reason = reason
	
	var result_str: String = "PASS" if passed else "FAIL"
	print("[%s] %.0f m/s @ %.0fcm - %s" % [result_str, test.max_speed, test.height * 100, reason])
	
	_current_test_index += 1
	
	await get_tree().create_timer(0.3).timeout
	_start_next_test()


func _finish_all_tests() -> void:
	_state = TestState.COMPLETE
	Input.action_release("accelerate")
	
	var passed_count: int = 0
	var total_count: int = _all_tests.size()
	
	var results_text: String = "=== TIRE GRIP RESULTS ===\n\n"
	
	for test in _all_tests:
		var status: String = "PASS" if test.passed else "FAIL"
		if test.passed:
			passed_count += 1
		results_text += "[%s] %.0fm/s @ %.0fcm: %s\n" % [status, test.max_speed, test.height * 100, test.reason]
	
	results_text += "\n%d / %d passed" % [passed_count, total_count]
	
	_results_label.text = results_text
	_status_label.text = "DONE: %d/%d (R=restart)" % [passed_count, total_count]
	
	print("\n" + results_text)
	
	if passed_count == total_count:
		_status_label.modulate = Color.GREEN
	elif passed_count > total_count / 2:
		_status_label.modulate = Color.YELLOW
	else:
		_status_label.modulate = Color.RED


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		print("\n=== RESTART ===\n")
		_current_test_index = 0
		_test_in_progress = false
		_state = TestState.IDLE
		Input.action_release("accelerate")
		for test in _all_tests:
			test.passed = false
			test.reason = ""
		_bike.reset_position(Vector3(0, 1.5, -8))
		await get_tree().create_timer(1.0).timeout
		_start_next_test()
	
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
