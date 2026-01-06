extends CanvasLayer

@onready var _panel: PanelContainer = $Panel
@onready var _status: Label = $Panel/VBox/StatusLabel
@onready var _unlock_btn: Button = $Panel/VBox/UnlockAllBtn
@onready var _add_10k_btn: Button = $Panel/VBox/Add10kBtn
@onready var _add_100k_btn: Button = $Panel/VBox/Add100kBtn
@onready var _max_speed_btn: Button = $Panel/VBox/MaxSpeedBtn
@onready var _max_upgrades_btn: Button = $Panel/VBox/MaxAllUpgradesBtn
@onready var _skip_stage_btn: Button = $Panel/VBox/SkipStageBtn


func _ready() -> void:
	_unlock_btn.pressed.connect(_on_unlock_all)
	_add_10k_btn.pressed.connect(_on_add_10k)
	_add_100k_btn.pressed.connect(_on_add_100k)
	_max_speed_btn.pressed.connect(_on_max_speed)
	_max_upgrades_btn.pressed.connect(_on_max_upgrades)
	_skip_stage_btn.pressed.connect(_on_skip_stage)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle_panel()
		get_viewport().set_input_as_handled()


func toggle_panel() -> void:
	_panel.visible = not _panel.visible
	if _panel.visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		get_tree().paused = true
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_tree().paused = false


func _set_status(text: String) -> void:
	_status.text = text


func _on_unlock_all() -> void:
	Economy.wallet = 99999
	BikeData.owned_bikes = ["starter", "needle", "rocket", "tankette"]
	BikeData.upgrade_tiers = {
		"top_speed": 5,
		"acceleration": 5,
		"handling": 5,
		"stability": 5,
		"jump_efficiency": 5
	}
	GameManager.best_stage = 5
	_set_status("Everything unlocked!")


func _on_add_10k() -> void:
	Economy.wallet += 10000
	_set_status("Wallet: %d" % Economy.wallet)


func _on_add_100k() -> void:
	Economy.wallet += 100000
	_set_status("Wallet: %d" % Economy.wallet)


func _on_max_speed() -> void:
	BikeData.upgrade_tiers["top_speed"] = 5
	_set_status("Speed maxed!")


func _on_max_upgrades() -> void:
	BikeData.upgrade_tiers = {
		"top_speed": 5,
		"acceleration": 5,
		"handling": 5,
		"stability": 5,
		"jump_efficiency": 5
	}
	_set_status("All upgrades maxed!")


func _on_skip_stage() -> void:
	if RunManager.current_state == RunManager.RunState.IN_RUN:
		RunManager.complete_stage()
		_set_status("Stage completed!")
	else:
		_set_status("Not in a run!")
