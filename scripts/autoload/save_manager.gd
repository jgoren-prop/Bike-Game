extends Node
class_name SaveManagerClass

## Stub save manager for physics sandbox - no persistence needed

const SAVE_PATH: String = "user://sandbox_save.json"


func _ready() -> void:
	pass


func save_game() -> void:
	# No-op for sandbox mode
	pass


func load_game() -> void:
	# No-op for sandbox mode
	pass


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
