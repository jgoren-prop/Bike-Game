extends Node
class_name RunManagerClass

## Manages run state, stage progression, and timing

enum RunState { IDLE, IN_RUN, STAGE_COMPLETE, RUN_FAILED }

const STAGE_TIME_LIMITS: Array[float] = [0.0, 180.0]
const MAX_STAGE: int = 1
const STAGE_SCENES: Array[String] = [
	"",
	"res://scenes/stages/volcanic_gauntlet.tscn"
]

var current_state: RunState = RunState.IDLE
var current_stage: int = 0
var stage_time_remaining: float = 0.0
var stage_time_elapsed: float = 0.0
var _timer_active: bool = false

signal run_started
signal stage_started(stage_num: int)
signal stage_cleared(stage_num: int, time_taken: float)
signal run_failed(reason: String)
signal run_cashed_out(total_pot: int)
signal time_updated(time_remaining: float)


func _process(delta: float) -> void:
	if _timer_active and current_state == RunState.IN_RUN:
		stage_time_elapsed += delta
		stage_time_remaining -= delta
		time_updated.emit(stage_time_remaining)

		if stage_time_remaining <= 0.0:
			fail_run("Time ran out")


func start_run() -> void:
	current_stage = 1
	current_state = RunState.IN_RUN
	Economy.set_pot_for_stage(current_stage)
	_start_stage_timer()
	GameManager.total_runs += 1
	run_started.emit()
	stage_started.emit(current_stage)


func _start_stage_timer() -> void:
	if current_stage < STAGE_TIME_LIMITS.size():
		stage_time_remaining = STAGE_TIME_LIMITS[current_stage]
	else:
		stage_time_remaining = 100.0
	stage_time_elapsed = 0.0
	_timer_active = true


func complete_stage() -> void:
	_timer_active = false
	current_state = RunState.STAGE_COMPLETE
	stage_cleared.emit(current_stage, stage_time_elapsed)


func fail_run(reason: String) -> void:
	_timer_active = false
	current_state = RunState.RUN_FAILED
	Economy.lose_pot()
	run_failed.emit(reason)


func cash_out() -> void:
	var total: int = Economy.pot
	# Track best stage
	if current_stage > GameManager.best_stage:
		GameManager.best_stage = current_stage
	Economy.cash_out()
	current_state = RunState.IDLE
	current_stage = 0
	run_cashed_out.emit(total)


func continue_to_next_stage() -> void:
	if current_stage >= MAX_STAGE:
		cash_out()
		return

	current_stage += 1
	Economy.set_pot_for_stage(current_stage)
	current_state = RunState.IN_RUN
	_start_stage_timer()
	stage_started.emit(current_stage)


func get_next_stage_pot() -> int:
	if current_stage >= MAX_STAGE:
		return Economy.pot
	return Economy.calculate_pot_for_stage(current_stage + 1)


func get_time_limit_for_stage(stage: int) -> float:
	if stage < STAGE_TIME_LIMITS.size():
		return STAGE_TIME_LIMITS[stage]
	return 100.0


func get_stage_scene_path(stage: int) -> String:
	if stage > 0 and stage < STAGE_SCENES.size():
		return STAGE_SCENES[stage]
	return ""
