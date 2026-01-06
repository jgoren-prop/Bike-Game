extends CanvasLayer
class_name BikeShop

## Bike selection and purchase UI

@onready var panel: PanelContainer = $Panel
@onready var bike_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/BikeContainer
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton

var _bike_buttons: Dictionary = {}

signal closed


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	_build_bike_list()
	hide()


func _build_bike_list() -> void:
	# Clear existing
	for child in bike_container.get_children():
		child.queue_free()
	_bike_buttons.clear()

	# Add bike entries
	for bike_id in BikeData.get_all_bike_ids():
		var stats: Dictionary = BikeData.get_base_stats(bike_id)
		var entry: HBoxContainer = _create_bike_entry(bike_id, stats)
		bike_container.add_child(entry)


func _create_bike_entry(bike_id: String, stats: Dictionary) -> HBoxContainer:
	var entry := HBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Bike name and stats
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = stats["name"]
	name_label.add_theme_font_size_override("font_size", 20)
	info.add_child(name_label)

	var stats_label := Label.new()
	stats_label.text = "SPD:%d ACC:%d HND:%d STB:%d JMP:%d" % [
		int(stats["top_speed"]),
		int(stats["acceleration"]),
		int(stats["handling"]),
		int(stats["stability"]),
		int(stats["jump_efficiency"])
	]
	stats_label.add_theme_font_size_override("font_size", 12)
	stats_label.modulate = Color(0.7, 0.7, 0.7)
	info.add_child(stats_label)

	entry.add_child(info)

	# Button
	var button := Button.new()
	button.custom_minimum_size = Vector2(120, 40)
	_update_button_state(button, bike_id, stats)
	button.pressed.connect(_on_bike_button_pressed.bind(bike_id, button))
	entry.add_child(button)

	_bike_buttons[bike_id] = button
	return entry


func _update_button_state(button: Button, bike_id: String, stats: Dictionary) -> void:
	if BikeData.selected_bike == bike_id:
		button.text = "SELECTED"
		button.disabled = true
	elif BikeData.is_bike_owned(bike_id):
		button.text = "SELECT"
		button.disabled = false
	else:
		button.text = "$%d" % stats["cost"]
		button.disabled = not Economy.can_afford(stats["cost"])


func _on_bike_button_pressed(bike_id: String, button: Button) -> void:
	var stats: Dictionary = BikeData.get_base_stats(bike_id)

	if BikeData.is_bike_owned(bike_id):
		BikeData.select_bike(bike_id)
	else:
		BikeData.purchase_bike(bike_id)
		BikeData.select_bike(bike_id)

	_refresh_all_buttons()


func _refresh_all_buttons() -> void:
	for bike_id in _bike_buttons:
		var button: Button = _bike_buttons[bike_id]
		var stats: Dictionary = BikeData.get_base_stats(bike_id)
		_update_button_state(button, bike_id, stats)


func _on_close_pressed() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func open() -> void:
	_refresh_all_buttons()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
