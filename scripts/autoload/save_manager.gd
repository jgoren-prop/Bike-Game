extends Node
class_name SaveManagerClass

## Handles saving and loading game data to/from user://save.json

const SAVE_PATH: String = "user://save.json"

var _save_data: Dictionary = {}


func _ready() -> void:
	load_game()


func save_game() -> void:
	_save_data = {
		"wallet": Economy.wallet,
		"owned_bikes": BikeData.owned_bikes,
		"selected_bike": BikeData.selected_bike,
		"upgrade_tiers": BikeData.upgrade_tiers,
		"stats": {
			"best_stage": GameManager.best_stage,
			"total_runs": GameManager.total_runs,
			"total_earnings": GameManager.total_earnings
		}
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(_save_data, "\t"))
		file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json := JSON.new()
	var error := json.parse(json_string)
	if error != OK:
		push_warning("Failed to parse save file: %s" % json.get_error_message())
		return

	_save_data = json.data
	_apply_save_data()


func _apply_save_data() -> void:
	if _save_data.has("wallet"):
		Economy.wallet = _save_data["wallet"]

	if _save_data.has("owned_bikes"):
		# Convert generic Array to typed Array[String]
		BikeData.owned_bikes.clear()
		for bike in _save_data["owned_bikes"]:
			BikeData.owned_bikes.append(bike)

	if _save_data.has("selected_bike"):
		BikeData.selected_bike = _save_data["selected_bike"]

	if _save_data.has("upgrade_tiers"):
		# Copy dictionary values individually to avoid type issues
		for key in _save_data["upgrade_tiers"]:
			BikeData.upgrade_tiers[key] = _save_data["upgrade_tiers"][key]

	if _save_data.has("stats"):
		var stats: Dictionary = _save_data["stats"]
		if stats.has("best_stage"):
			GameManager.best_stage = stats["best_stage"]
		if stats.has("total_runs"):
			GameManager.total_runs = stats["total_runs"]
		if stats.has("total_earnings"):
			GameManager.total_earnings = stats["total_earnings"]


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)

	Economy.wallet = 0
	BikeData.owned_bikes = ["starter"]
	BikeData.selected_bike = "starter"
	BikeData.upgrade_tiers = {
		"speed": 0,
		"acceleration": 0,
		"handling": 0,
		"stability": 0,
		"jump_efficiency": 0
	}
	GameManager.best_stage = 0
	GameManager.total_runs = 0
	GameManager.total_earnings = 0
