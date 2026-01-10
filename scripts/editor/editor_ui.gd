extends Control
class_name EditorUI

## UI for the level editor
## Prefab palette, tool buttons, mode toggle

signal prefab_selected(prefab_path: String)
signal mode_toggle_pressed
signal grid_size_changed(size: float)
signal clear_level_pressed
signal save_pressed(level_name: String)
signal load_pressed(level_name: String)

# Prefab categories and paths
const PREFAB_CATEGORIES: Dictionary = {
	"Platforms": [
		{"name": "Small Platform", "path": "res://scenes/editor/prefabs/platforms/platform_small.tscn"},
		{"name": "Medium Platform", "path": "res://scenes/editor/prefabs/platforms/platform_medium.tscn"},
		{"name": "Large Platform", "path": "res://scenes/editor/prefabs/platforms/platform_large.tscn"},
		{"name": "Narrow Platform", "path": "res://scenes/editor/prefabs/platforms/platform_narrow.tscn"},
	],
	"Ramps": [
		{"name": "Gentle Ramp (15°)", "path": "res://scenes/editor/prefabs/ramps/ramp_gentle.tscn"},
		{"name": "Medium Ramp (25°)", "path": "res://scenes/editor/prefabs/ramps/ramp_medium.tscn"},
		{"name": "Steep Ramp (35°)", "path": "res://scenes/editor/prefabs/ramps/ramp_steep.tscn"},
		{"name": "Launch Ramp (45°)", "path": "res://scenes/editor/prefabs/ramps/ramp_launch.tscn"},
		{"name": "Landing Ramp", "path": "res://scenes/editor/prefabs/ramps/ramp_landing.tscn"},
	],
	"Obstacles": [
		{"name": "Seesaw", "path": "res://scenes/editor/prefabs/obstacles/seesaw.tscn"},
		{"name": "Rotating Barrier", "path": "res://scenes/editor/prefabs/obstacles/rotating_barrier.tscn"},
		{"name": "Falling Platform", "path": "res://scenes/editor/prefabs/obstacles/falling_platform.tscn"},
		{"name": "Moving Platform", "path": "res://scenes/editor/prefabs/obstacles/moving_platform.tscn"},
	],
	"Stunts": [
		{"name": "Loop", "path": "res://scenes/editor/prefabs/stunts/loop_full.tscn"},
		{"name": "Half-Pipe", "path": "res://scenes/editor/prefabs/stunts/halfpipe.tscn"},
		{"name": "Wall Ride Left", "path": "res://scenes/editor/prefabs/stunts/wallride_left.tscn"},
		{"name": "Wall Ride Right", "path": "res://scenes/editor/prefabs/stunts/wallride_right.tscn"},
	],
	"Special": [
		{"name": "Spawn Point", "path": "res://scenes/editor/prefabs/special/spawn_point.tscn"},
		{"name": "Finish Gate", "path": "res://scenes/editor/prefabs/special/finish_gate.tscn"},
		{"name": "Checkpoint", "path": "res://scenes/editor/prefabs/special/checkpoint.tscn"},
	],
}

var _current_category: String = ""
var _selected_prefab: String = ""

@onready var _category_list: ItemList = $LeftPanel/VBox/CategoryList
@onready var _prefab_list: ItemList = $LeftPanel/VBox/PrefabList
@onready var _mode_button: Button = $TopBar/HBox/ModeButton
@onready var _grid_option: OptionButton = $TopBar/HBox/GridOption
@onready var _clear_button: Button = $TopBar/HBox/ClearButton
@onready var _save_button: Button = $TopBar/HBox/SaveButton
@onready var _load_button: Button = $TopBar/HBox/LoadButton
@onready var _tool_info: Label = $TopBar/HBox/ToolInfo
@onready var _tool_label: Label = $TopBar/HBox/ToolLabel
@onready var _grid_label: Label = $TopBar/HBox/GridLabel
@onready var _info_label: Label = $BottomBar/InfoLabel
@onready var _left_panel: PanelContainer = $LeftPanel
@onready var _top_bar: PanelContainer = $TopBar
@onready var _bottom_bar: PanelContainer = $BottomBar


func _ready() -> void:
	_setup_category_list()
	_setup_grid_options()
	_connect_signals()
	_update_info_label()
	# Auto-select first category
	if _category_list.item_count > 0:
		_category_list.select(0)
		_on_category_selected(0)


func _setup_category_list() -> void:
	_category_list.clear()
	for category in PREFAB_CATEGORIES.keys():
		_category_list.add_item(category)


func _setup_grid_options() -> void:
	_grid_option.clear()
	_grid_option.add_item("0.5m Grid", 0)
	_grid_option.add_item("1m Grid", 1)
	_grid_option.add_item("2m Grid", 2)
	_grid_option.add_item("4m Grid", 3)
	_grid_option.select(2)  # Default 2m


func _connect_signals() -> void:
	_category_list.item_selected.connect(_on_category_selected)
	_prefab_list.item_selected.connect(_on_prefab_item_selected)
	_mode_button.pressed.connect(_on_mode_button_pressed)
	_grid_option.item_selected.connect(_on_grid_option_selected)
	_clear_button.pressed.connect(_on_clear_button_pressed)
	_save_button.pressed.connect(_on_save_button_pressed)
	_load_button.pressed.connect(_on_load_button_pressed)


func _on_category_selected(index: int) -> void:
	var category := _category_list.get_item_text(index)
	_current_category = category
	_update_prefab_list(category)


func _update_prefab_list(category: String) -> void:
	_prefab_list.clear()
	
	if not PREFAB_CATEGORIES.has(category):
		return
	
	var prefabs: Array = PREFAB_CATEGORIES[category]
	for prefab in prefabs:
		_prefab_list.add_item(prefab["name"])


func _on_prefab_item_selected(index: int) -> void:
	if _current_category.is_empty():
		return
	
	var prefabs: Array = PREFAB_CATEGORIES[_current_category]
	if index < 0 or index >= prefabs.size():
		return
	
	var prefab_data: Dictionary = prefabs[index]
	_selected_prefab = prefab_data["path"]
	prefab_selected.emit(_selected_prefab)
	_update_info_label()


func _on_mode_button_pressed() -> void:
	mode_toggle_pressed.emit()


func _on_grid_option_selected(index: int) -> void:
	var sizes: Array[float] = [0.5, 1.0, 2.0, 4.0]
	if index >= 0 and index < sizes.size():
		grid_size_changed.emit(sizes[index])


func _on_clear_button_pressed() -> void:
	# Confirmation would be nice here
	clear_level_pressed.emit()


func _on_save_button_pressed() -> void:
	# For now, use a default name - will add dialog in Phase 5
	save_pressed.emit("custom_level")


func _on_load_button_pressed() -> void:
	# Will add file browser in Phase 5
	load_pressed.emit("custom_level")


var _is_place_mode: bool = true
var _transform_tool: String = "Move"
var _snap_enabled: bool = true
var _snap_move: float = 1.0
var _snap_rotate: float = 15.0
var _snap_scale: float = 0.25

func _update_info_label() -> void:
	var info: String
	if _is_place_mode:
		info = "Click: Place | R/T: Rotate | Q/E: Height | Esc: Cancel"
		if not _selected_prefab.is_empty():
			var prefab_name := _selected_prefab.get_file().get_basename()
			info = prefab_name + " | " + info
	else:
		var snap_status := "ON" if _snap_enabled else "OFF"
		var snap_info := ""
		if _snap_enabled:
			match _transform_tool:
				"Move":
					snap_info = " (%.1fm)" % _snap_move
				"Rotate":
					snap_info = " (%.0f°)" % _snap_rotate
				"Scale":
					snap_info = " (%.2f)" % _snap_scale
		info = "W/E/R: Tool | G: Snap %s%s | Drag: Transform | Tool: %s" % [snap_status, snap_info, _transform_tool]
	_info_label.text = info


func set_place_mode(is_place: bool) -> void:
	_is_place_mode = is_place
	_update_info_label()


func set_transform_tool(tool_name: String) -> void:
	_transform_tool = tool_name
	if not _is_place_mode:
		_update_info_label()


func set_mode_button_text(text: String) -> void:
	_mode_button.text = text


func set_play_mode_ui() -> void:
	# Hide most UI, show only mode toggle
	_left_panel.visible = false
	_bottom_bar.visible = false
	_save_button.visible = false
	_load_button.visible = false
	_clear_button.visible = false
	_grid_option.visible = false
	_grid_label.visible = false
	_tool_info.visible = false
	_tool_label.visible = false
	_mode_button.text = "Edit (Tab)"


func set_edit_mode_ui() -> void:
	# Show all UI
	_left_panel.visible = true
	_bottom_bar.visible = true
	_save_button.visible = true
	_load_button.visible = true
	_clear_button.visible = true
	_grid_option.visible = true
	_grid_label.visible = true
	_tool_info.visible = true
	_tool_label.visible = true
	_mode_button.text = "Play (Tab)"
	_update_info_label()


func set_tool_info(tool_name: String) -> void:
	if _tool_info:
		_tool_info.text = tool_name


func set_snap_enabled(enabled: bool) -> void:
	_snap_enabled = enabled
	_update_info_label()


func set_snap_values(move: float, rotate: float, scale_val: float) -> void:
	_snap_move = move
	_snap_rotate = rotate
	_snap_scale = scale_val
	_update_info_label()

