extends CanvasLayer
class_name RunHUD

## HUD displayed during runs - shows time, stage, pot, and trick notifications

@onready var time_label: Label = $MarginContainer/VBoxContainer/TimeLabel
@onready var stage_label: Label = $MarginContainer/VBoxContainer/StageLabel
@onready var pot_label: Label = $MarginContainer/VBoxContainer/PotLabel
@onready var flip_notification: FlipNotification = $FlipNotification

var _bike: BikeController = null


func _ready() -> void:
	RunManager.stage_started.connect(_on_stage_started)
	Economy.pot_changed.connect(_on_pot_changed)

	_update_stage_display(RunManager.current_stage)
	_update_pot_display(Economy.pot)
	
	# Hide timer - no time limit
	if time_label:
		time_label.visible = false
	
	# Find and connect to bike (deferred to ensure scene is fully loaded)
	call_deferred("_find_and_connect_bike")


func _find_and_connect_bike() -> void:
	## Find the bike in the scene tree and connect to its flip signal
	# Try to find bike in the current scene
	var bikes: Array[Node] = get_tree().get_nodes_in_group("bike")
	if bikes.size() > 0 and bikes[0] is BikeController:
		_connect_to_bike(bikes[0] as BikeController)
	else:
		# Fallback: search for BikeController in scene
		var root: Node = get_tree().current_scene
		if root:
			_search_for_bike(root)


func _search_for_bike(node: Node) -> void:
	if node is BikeController:
		_connect_to_bike(node as BikeController)
		return
	for child in node.get_children():
		_search_for_bike(child)


func _connect_to_bike(bike: BikeController) -> void:
	if _bike == bike:
		return  # Already connected
	_bike = bike
	if not _bike.flip_completed.is_connected(_on_flip_completed):
		_bike.flip_completed.connect(_on_flip_completed)
		print("[HUD] Connected to bike flip signal!")


func _on_flip_completed(flip_type: String, rotation_count: int) -> void:
	print("[HUD] Received flip: %s x%d" % [flip_type, rotation_count])
	if flip_notification:
		flip_notification.show_flip(flip_type, rotation_count)
	else:
		print("[HUD] ERROR: flip_notification is null!")


func _on_stage_started(stage_num: int) -> void:
	_update_stage_display(stage_num)


func _update_stage_display(stage_num: int) -> void:
	stage_label.text = "STAGE %d" % stage_num


func _on_pot_changed(new_pot: int) -> void:
	_update_pot_display(new_pot)


func _update_pot_display(pot: int) -> void:
	pot_label.text = "POT: $%d" % pot
