extends CanvasLayer
class_name ClimbHUD

## Minimalist HUD for rage game - shows height only

@onready var height_label: Label = $MarginContainer/VBoxContainer/HeightLabel
@onready var best_label: Label = $MarginContainer/VBoxContainer/BestLabel


func _ready() -> void:
	ClimbManager.height_updated.connect(_on_height_updated)
	ClimbManager.new_best_height.connect(_on_new_best)
	_update_display()


func _on_height_updated(height: float) -> void:
	_update_display()


func _on_new_best(height: float) -> void:
	_update_display()


func _update_display() -> void:
	if height_label:
		height_label.text = "%.1fm" % ClimbManager.current_height
	if best_label:
		best_label.text = "BEST: %.1fm" % ClimbManager.best_height
