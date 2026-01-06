extends Node3D
class_name Hub

## Hub scene - player starts runs from here, accesses shops

@onready var start_gate: Area3D = $StartGate
@onready var bike_shop_area: Area3D = $BikeShopArea
@onready var upgrade_shop_area: Area3D = $UpgradeShopArea
@onready var spawn_point: Marker3D = $SpawnPoint
@onready var wallet_label: Label = $HubUI/MarginContainer/VBoxContainer/WalletLabel
@onready var best_stage_label: Label = $HubUI/MarginContainer/VBoxContainer/BestStageLabel
@onready var prompt_label: Label = $HubUI/PromptLabel

var _player_bike: BikeController
var _best_stage: int = 0
var _bike_shop: BikeShop
var _upgrade_shop: UpgradeShop
var _near_bike_shop: bool = false
var _near_upgrade_shop: bool = false
var _shop_open: bool = false


func _ready() -> void:
	_spawn_player()
	_setup_gates()
	_setup_shops()
	_update_ui()
	Economy.wallet_changed.connect(_on_wallet_changed)


func _spawn_player() -> void:
	var bike_scene: PackedScene = preload("res://scenes/bike/bike.tscn")
	_player_bike = bike_scene.instantiate()
	add_child(_player_bike)

	if spawn_point:
		_player_bike.global_position = spawn_point.global_position


func _setup_gates() -> void:
	if start_gate:
		start_gate.body_entered.connect(_on_start_gate_entered)

	if bike_shop_area:
		bike_shop_area.body_entered.connect(_on_bike_shop_entered)
		bike_shop_area.body_exited.connect(_on_bike_shop_exited)

	if upgrade_shop_area:
		upgrade_shop_area.body_entered.connect(_on_upgrade_shop_entered)
		upgrade_shop_area.body_exited.connect(_on_upgrade_shop_exited)


func _setup_shops() -> void:
	var bike_shop_scene: PackedScene = preload("res://scenes/ui/bike_shop.tscn")
	_bike_shop = bike_shop_scene.instantiate()
	add_child(_bike_shop)
	_bike_shop.closed.connect(_on_shop_closed)

	var upgrade_shop_scene: PackedScene = preload("res://scenes/ui/upgrade_shop.tscn")
	_upgrade_shop = upgrade_shop_scene.instantiate()
	add_child(_upgrade_shop)
	_upgrade_shop.closed.connect(_on_shop_closed)


func _process(_delta: float) -> void:
	if _shop_open:
		return

	# Update prompt
	if _near_bike_shop:
		prompt_label.text = "Press E - Bike Shop"
		prompt_label.show()
	elif _near_upgrade_shop:
		prompt_label.text = "Press E - Upgrades"
		prompt_label.show()
	else:
		prompt_label.hide()

	# Handle interaction
	if Input.is_action_just_pressed("interact"):
		if _near_bike_shop:
			_open_bike_shop()
		elif _near_upgrade_shop:
			_open_upgrade_shop()


func _on_start_gate_entered(body: Node3D) -> void:
	if body == _player_bike and not _shop_open:
		_start_run()


func _on_bike_shop_entered(body: Node3D) -> void:
	if body == _player_bike:
		_near_bike_shop = true


func _on_bike_shop_exited(body: Node3D) -> void:
	if body == _player_bike:
		_near_bike_shop = false


func _on_upgrade_shop_entered(body: Node3D) -> void:
	if body == _player_bike:
		_near_upgrade_shop = true


func _on_upgrade_shop_exited(body: Node3D) -> void:
	if body == _player_bike:
		_near_upgrade_shop = false


func _open_bike_shop() -> void:
	_shop_open = true
	_bike_shop.open()


func _open_upgrade_shop() -> void:
	_shop_open = true
	_upgrade_shop.open()


func _on_shop_closed() -> void:
	_shop_open = false


func _start_run() -> void:
	get_tree().change_scene_to_file("res://scenes/stages/test_stage.tscn")


func _update_ui() -> void:
	if wallet_label:
		wallet_label.text = "WALLET: $%d" % Economy.wallet
	if best_stage_label:
		best_stage_label.text = "BEST: Stage %d" % _best_stage


func _on_wallet_changed(_new_amount: int) -> void:
	_update_ui()
