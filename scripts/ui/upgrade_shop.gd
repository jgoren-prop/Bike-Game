extends CanvasLayer
class_name UpgradeShop

## Upgrade purchase UI

const UPGRADE_NAMES: Dictionary = {
	"top_speed": "Speed",
	"acceleration": "Acceleration",
	"handling": "Handling",
	"stability": "Stability",
	"jump_efficiency": "Jump"
}

@onready var panel: PanelContainer = $Panel
@onready var upgrade_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/UpgradeContainer
@onready var close_button: Button = $Panel/MarginContainer/VBoxContainer/CloseButton
@onready var wallet_label: Label = $Panel/MarginContainer/VBoxContainer/WalletLabel

var _upgrade_buttons: Dictionary = {}

signal closed


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	Economy.wallet_changed.connect(_on_wallet_changed)
	_build_upgrade_list()
	hide()


func _build_upgrade_list() -> void:
	# Clear existing
	for child in upgrade_container.get_children():
		child.queue_free()
	_upgrade_buttons.clear()

	# Add upgrade entries
	for category in UPGRADE_NAMES:
		var entry: HBoxContainer = _create_upgrade_entry(category)
		upgrade_container.add_child(entry)


func _create_upgrade_entry(category: String) -> HBoxContainer:
	var entry := HBoxContainer.new()
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Category name
	var name_label := Label.new()
	name_label.text = UPGRADE_NAMES[category]
	name_label.custom_minimum_size = Vector2(100, 0)
	name_label.add_theme_font_size_override("font_size", 18)
	entry.add_child(name_label)

	# Tier indicators
	var tier_container := HBoxContainer.new()
	tier_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for i in range(BikeData.MAX_UPGRADE_TIER):
		var tier_box := ColorRect.new()
		tier_box.custom_minimum_size = Vector2(20, 20)
		tier_box.color = Color(0.2, 0.6, 0.2) if i < BikeData.upgrade_tiers[category] else Color(0.3, 0.3, 0.3)
		tier_container.add_child(tier_box)
	entry.add_child(tier_container)

	# Button
	var button := Button.new()
	button.custom_minimum_size = Vector2(100, 35)
	_update_button_state(button, category)
	button.pressed.connect(_on_upgrade_button_pressed.bind(category, button, tier_container))
	entry.add_child(button)

	_upgrade_buttons[category] = {"button": button, "tiers": tier_container}
	return entry


func _update_button_state(button: Button, category: String) -> void:
	var current_tier: int = BikeData.upgrade_tiers[category]

	if current_tier >= BikeData.MAX_UPGRADE_TIER:
		button.text = "MAX"
		button.disabled = true
	else:
		var cost: int = BikeData.get_upgrade_cost(current_tier)
		button.text = "$%d" % cost
		button.disabled = not Economy.can_afford(cost)


func _update_tier_display(tier_container: HBoxContainer, category: String) -> void:
	var current_tier: int = BikeData.upgrade_tiers[category]
	var boxes = tier_container.get_children()
	for i in range(boxes.size()):
		boxes[i].color = Color(0.2, 0.6, 0.2) if i < current_tier else Color(0.3, 0.3, 0.3)


func _on_upgrade_button_pressed(category: String, button: Button, tier_container: HBoxContainer) -> void:
	if BikeData.purchase_upgrade(category):
		_update_button_state(button, category)
		_update_tier_display(tier_container, category)


func _on_wallet_changed(_new_amount: int) -> void:
	_refresh_all_buttons()
	_update_wallet_display()


func _update_wallet_display() -> void:
	if wallet_label:
		wallet_label.text = "Wallet: $%d" % Economy.wallet


func _refresh_all_buttons() -> void:
	for category in _upgrade_buttons:
		var data: Dictionary = _upgrade_buttons[category]
		_update_button_state(data["button"], category)
		_update_tier_display(data["tiers"], category)


func _on_close_pressed() -> void:
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func open() -> void:
	_refresh_all_buttons()
	_update_wallet_display()
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
