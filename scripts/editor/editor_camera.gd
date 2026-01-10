extends Camera3D
class_name EditorCamera

## Free-fly camera for the level editor
## WASD movement, mouse look, scroll for speed, shift for fast

@export var base_speed: float = 10.0
@export var fast_multiplier: float = 3.0
@export var sensitivity: float = 0.003
@export var min_speed: float = 2.0
@export var max_speed: float = 50.0

var _current_speed: float = 10.0
var _yaw: float = 0.0
var _pitch: float = 0.0
var _active: bool = true


func _ready() -> void:
	# Initialize rotation from current transform
	_yaw = rotation.y
	_pitch = rotation.x


func look_at_point(target: Vector3) -> void:
	# Make the camera look at a target point and update yaw/pitch
	look_at(target, Vector3.UP)
	_yaw = rotation.y
	_pitch = rotation.x


func set_active(active: bool) -> void:
	_active = active
	if active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _input(event: InputEvent) -> void:
	if not _active:
		return
	
	# Mouse look
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * sensitivity
		_pitch -= event.relative.y * sensitivity
		_pitch = clamp(_pitch, -PI / 2.0 + 0.1, PI / 2.0 - 0.1)
		rotation = Vector3(_pitch, _yaw, 0)
	
	# Scroll wheel for speed adjustment
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_current_speed = min(_current_speed * 1.2, max_speed)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_current_speed = max(_current_speed / 1.2, min_speed)
	
	# Toggle mouse capture with right click
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		else:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(delta: float) -> void:
	if not _active:
		return
	
	# Only move when mouse is captured
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	
	# Movement input
	var input_dir := Vector3.ZERO
	
	if Input.is_key_pressed(KEY_W):
		input_dir.z -= 1
	if Input.is_key_pressed(KEY_S):
		input_dir.z += 1
	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_SPACE):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_Q) or Input.is_key_pressed(KEY_CTRL):
		input_dir.y -= 1
	
	if input_dir.length() > 0:
		input_dir = input_dir.normalized()
	
	# Apply speed multiplier
	var speed := _current_speed
	if Input.is_key_pressed(KEY_SHIFT):
		speed *= fast_multiplier
	
	# Transform direction to camera space and move
	var velocity := (global_transform.basis * input_dir) * speed
	global_position += velocity * delta


func get_current_speed() -> float:
	return _current_speed

