extends Node
class_name GameManagerClass

## Overall game state manager for rage game

enum GameState { MENU, PLAYING, PAUSED }

var current_state: GameState = GameState.MENU
var total_runs: int = 0
var best_stage: int = 0

signal state_changed(new_state: GameState)


func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func is_playing() -> bool:
	return current_state == GameState.PLAYING


func start_game() -> void:
	change_state(GameState.PLAYING)


func pause_game() -> void:
	if current_state == GameState.PLAYING:
		change_state(GameState.PAUSED)


func resume_game() -> void:
	if current_state == GameState.PAUSED:
		change_state(GameState.PLAYING)


func return_to_menu() -> void:
	change_state(GameState.MENU)
