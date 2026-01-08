extends Node
class_name ClimbManagerClass

## Manages climb progress and height tracking for rage game

enum ClimbState { MENU, CLIMBING, PAUSED }

var current_state: ClimbState = ClimbState.MENU
var current_height: float = 0.0
var best_height: float = 0.0
var total_attempts: int = 0
var total_play_time: float = 0.0
var _session_start_time: float = 0.0
var _session_play_time: float = 0.0

signal height_updated(height: float)
signal new_best_height(height: float)
signal attempt_started
signal fell
signal state_changed(new_state: ClimbState)


func _process(delta: float) -> void:
	if current_state == ClimbState.CLIMBING:
		_session_play_time += delta


func start_climbing() -> void:
	current_state = ClimbState.CLIMBING
	total_attempts += 1
	current_height = 0.0
	_session_start_time = Time.get_unix_time_from_system()
	attempt_started.emit()
	state_changed.emit(current_state)


func update_height(y_position: float) -> void:
	current_height = max(0.0, y_position)
	height_updated.emit(current_height)

	if current_height > best_height:
		best_height = current_height
		new_best_height.emit(best_height)


func on_fell() -> void:
	fell.emit()


func respawn() -> void:
	current_height = 0.0
	height_updated.emit(current_height)


func pause() -> void:
	if current_state == ClimbState.CLIMBING:
		current_state = ClimbState.PAUSED
		state_changed.emit(current_state)


func resume() -> void:
	if current_state == ClimbState.PAUSED:
		current_state = ClimbState.CLIMBING
		state_changed.emit(current_state)


func return_to_menu() -> void:
	total_play_time += _session_play_time
	_session_play_time = 0.0
	current_state = ClimbState.MENU
	current_height = 0.0
	state_changed.emit(current_state)


func get_session_time() -> float:
	return _session_play_time


func get_total_time() -> float:
	return total_play_time + _session_play_time


func load_data(data: Dictionary) -> void:
	best_height = data.get("best_height", 0.0)
	total_attempts = data.get("total_attempts", 0)
	total_play_time = data.get("total_play_time", 0.0)


func get_save_data() -> Dictionary:
	return {
		"best_height": best_height,
		"total_attempts": total_attempts,
		"total_play_time": get_total_time()
	}
