extends Node
class_name LevelSerializer

## Handles saving and loading custom levels to/from JSON files

const LEVELS_DIR := "user://custom_levels/"
const LEVEL_EXTENSION := ".json"

signal level_saved(level_name: String)
signal level_loaded(level_name: String)
signal save_failed(error: String)
signal load_failed(error: String)


func _ready() -> void:
	# Ensure the levels directory exists
	_ensure_directory_exists()


func _ensure_directory_exists() -> void:
	var dir := DirAccess.open("user://")
	if dir:
		if not dir.dir_exists("custom_levels"):
			dir.make_dir("custom_levels")


func save_level(level_name: String, placed_objects: Array[Node3D]) -> bool:
	"""Save all placed objects to a JSON file."""
	
	if level_name.is_empty():
		save_failed.emit("Level name cannot be empty")
		return false
	
	var level_data := {
		"name": level_name,
		"version": 1,
		"created": Time.get_datetime_string_from_system(),
		"objects": []
	}
	
	# Serialize each placed object
	for obj in placed_objects:
		if not is_instance_valid(obj):
			continue
		
		var prefab_path: String = obj.get_meta("prefab_path", "")
		if prefab_path.is_empty():
			push_warning("Object %s has no prefab_path, skipping" % obj.name)
			continue
		
		var object_data := {
			"prefab": prefab_path,
			"position": _vec3_to_array(obj.global_position),
			"rotation": _vec3_to_array(obj.global_rotation),
			"scale": _vec3_to_array(obj.scale)
		}
		
		level_data["objects"].append(object_data)
	
	# Write to file
	var file_path := LEVELS_DIR + level_name + LEVEL_EXTENSION
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	
	if not file:
		var error_msg := "Failed to open file for writing: %s" % file_path
		save_failed.emit(error_msg)
		push_error(error_msg)
		return false
	
	var json_string := JSON.stringify(level_data, "\t")
	file.store_string(json_string)
	file.close()
	
	level_saved.emit(level_name)
	print("Level saved: %s (%d objects)" % [level_name, level_data["objects"].size()])
	return true


func load_level(level_name: String, objects_container: Node3D, placed_objects: Array[Node3D]) -> bool:
	"""Load a level from JSON file, instantiate all objects."""
	
	if level_name.is_empty():
		load_failed.emit("Level name cannot be empty")
		return false
	
	var file_path := LEVELS_DIR + level_name + LEVEL_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		load_failed.emit("Level file not found: %s" % level_name)
		return false
	
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		load_failed.emit("Failed to open file: %s" % file_path)
		return false
	
	var json_string := file.get_as_text()
	file.close()
	
	var json := JSON.new()
	var parse_result := json.parse(json_string)
	
	if parse_result != OK:
		load_failed.emit("Failed to parse JSON: %s" % json.get_error_message())
		return false
	
	var level_data: Dictionary = json.data
	
	if not level_data.has("objects"):
		load_failed.emit("Invalid level format: missing 'objects' array")
		return false
	
	# Clear existing objects
	for obj in placed_objects:
		if is_instance_valid(obj):
			obj.queue_free()
	placed_objects.clear()
	
	# Load each object
	var objects_array: Array = level_data["objects"]
	var loaded_count := 0
	
	for object_data in objects_array:
		var prefab_path: String = object_data.get("prefab", "")
		if prefab_path.is_empty():
			push_warning("Object missing prefab path, skipping")
			continue
		
		if not ResourceLoader.exists(prefab_path):
			push_warning("Prefab not found: %s" % prefab_path)
			continue
		
		var prefab: PackedScene = load(prefab_path)
		if not prefab:
			push_warning("Failed to load prefab: %s" % prefab_path)
			continue
		
		var instance := prefab.instantiate()
		objects_container.add_child(instance)
		
		# Apply transform
		instance.global_position = _array_to_vec3(object_data.get("position", [0, 0, 0]))
		instance.global_rotation = _array_to_vec3(object_data.get("rotation", [0, 0, 0]))
		instance.scale = _array_to_vec3(object_data.get("scale", [1, 1, 1]))
		
		# Store prefab path for re-serialization
		instance.set_meta("prefab_path", prefab_path)
		
		placed_objects.append(instance)
		loaded_count += 1
	
	level_loaded.emit(level_name)
	print("Level loaded: %s (%d objects)" % [level_name, loaded_count])
	return true


func get_saved_levels() -> Array[String]:
	"""Return a list of all saved level names."""
	var levels: Array[String] = []
	
	var dir := DirAccess.open(LEVELS_DIR)
	if not dir:
		return levels
	
	dir.list_dir_begin()
	var file_name := dir.get_next()
	
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(LEVEL_EXTENSION):
			var level_name := file_name.get_basename()
			levels.append(level_name)
		file_name = dir.get_next()
	
	dir.list_dir_end()
	return levels


func delete_level(level_name: String) -> bool:
	"""Delete a saved level file."""
	var file_path := LEVELS_DIR + level_name + LEVEL_EXTENSION
	
	if not FileAccess.file_exists(file_path):
		return false
	
	var dir := DirAccess.open(LEVELS_DIR)
	if dir:
		return dir.remove(level_name + LEVEL_EXTENSION) == OK
	
	return false


func _vec3_to_array(v: Vector3) -> Array:
	return [v.x, v.y, v.z]


func _array_to_vec3(arr: Array) -> Vector3:
	if arr.size() < 3:
		return Vector3.ZERO
	return Vector3(arr[0], arr[1], arr[2])

