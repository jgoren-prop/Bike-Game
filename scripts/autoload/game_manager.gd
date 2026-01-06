extends Node
class_name GameManagerClass

## Overall game state manager

enum GameState { MENU, HUB, IN_RUN, PAUSED }

var current_state: GameState = GameState.HUB

# Stats tracking
var best_stage: int = 0
var total_runs: int = 0
var total_earnings: int = 0

signal state_changed(new_state: GameState)


func change_state(new_state: GameState) -> void:
	current_state = new_state
	state_changed.emit(new_state)


func is_in_run() -> bool:
	return current_state == GameState.IN_RUN
