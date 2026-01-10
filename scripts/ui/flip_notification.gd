extends Control
class_name FlipNotification

## Flashy trick notification popup - video game style!
## Shows trick name with animated points when bike completes a flip

# Points range for random bonus
const MIN_POINTS: int = 50
const MAX_POINTS: int = 250
const POINT_STEP: int = 25  # Round to nearest 25

# Animation timing
const SLAM_DURATION: float = 0.15
const HOLD_DURATION: float = 1.2
const FADE_DURATION: float = 0.4

# Visual shake settings
const SHAKE_INTENSITY: float = 8.0
const SHAKE_DECAY: float = 10.0

@onready var trick_label: Label = $CenterContainer/VBoxContainer/TrickLabel
@onready var points_label: Label = $CenterContainer/VBoxContainer/PointsLabel
@onready var combo_label: Label = $CenterContainer/VBoxContainer/ComboLabel
@onready var container: Control = $CenterContainer

var _shake_offset: Vector2 = Vector2.ZERO
var _shake_strength: float = 0.0
var _original_position: Vector2 = Vector2.ZERO
var _tween: Tween


func _ready() -> void:
	# Start hidden
	visible = false
	modulate.a = 0.0
	if container:
		_original_position = container.position


func _process(delta: float) -> void:
	# Apply screen shake decay
	if _shake_strength > 0.01:
		_shake_strength = lerpf(_shake_strength, 0.0, SHAKE_DECAY * delta)
		_shake_offset = Vector2(
			randf_range(-1.0, 1.0) * _shake_strength,
			randf_range(-1.0, 1.0) * _shake_strength
		)
		if container:
			container.position = _original_position + _shake_offset
	else:
		_shake_strength = 0.0
		if container:
			container.position = _original_position


func show_flip(trick_name: String, flip_count: int) -> void:
	## Display a flashy flip notification with random bonus points
	
	# Cancel any existing animation
	if _tween and _tween.is_valid():
		_tween.kill()
	
	# Calculate random bonus points (rounded to step)
	var raw_points: int = randi_range(MIN_POINTS, MAX_POINTS)
	var bonus_points: int = (raw_points / POINT_STEP) * POINT_STEP
	
	# Scale points by flip count (double flip = double points!)
	bonus_points *= flip_count
	
	# Award the points
	Economy.add_to_pot(bonus_points)
	
	# Set up the labels
	var display_name: String = trick_name
	if flip_count > 1:
		display_name = _get_multiplier_prefix(flip_count) + " " + trick_name
	
	trick_label.text = display_name + "!"
	points_label.text = "+$%d" % bonus_points
	
	# Show combo indicator for multiple flips
	if flip_count > 1:
		combo_label.text = "x%d COMBO!" % flip_count
		combo_label.visible = true
	else:
		combo_label.visible = false
	
	# Reset state
	visible = true
	modulate.a = 0.0
	scale = Vector2(2.5, 2.5)
	_shake_strength = 0.0
	
	# Color the labels based on trick type
	_apply_trick_colors(trick_name, flip_count)
	
	# Create slam-in animation
	_tween = create_tween()
	_tween.set_ease(Tween.EASE_OUT)
	_tween.set_trans(Tween.TRANS_BACK)
	
	# Slam in with scale and fade
	_tween.tween_property(self, "modulate:a", 1.0, SLAM_DURATION)
	_tween.parallel().tween_property(self, "scale", Vector2.ONE, SLAM_DURATION)
	
	# Trigger screen shake on slam
	_tween.tween_callback(_trigger_shake)
	
	# Hold for a moment
	_tween.tween_interval(HOLD_DURATION)
	
	# Fade out with slight upward drift
	_tween.set_ease(Tween.EASE_IN)
	_tween.set_trans(Tween.TRANS_QUAD)
	_tween.tween_property(self, "modulate:a", 0.0, FADE_DURATION)
	_tween.parallel().tween_property(self, "position:y", position.y - 50, FADE_DURATION)
	
	# Hide when done
	_tween.tween_callback(_on_animation_complete)


func _trigger_shake() -> void:
	_shake_strength = SHAKE_INTENSITY


func _on_animation_complete() -> void:
	visible = false
	position.y += 50  # Reset position for next time


func _get_multiplier_prefix(count: int) -> String:
	match count:
		2: return "DOUBLE"
		3: return "TRIPLE"
		4: return "QUAD"
		5: return "PENTA"
		_: return "%dX" % count


func _apply_trick_colors(trick_name: String, flip_count: int) -> void:
	## Apply exciting colors based on trick type and combo level
	
	var primary_color: Color
	var secondary_color: Color
	
	# Base color by trick type
	if "BACK" in trick_name:
		# Backflip = electric blue/cyan
		primary_color = Color(0.2, 0.9, 1.0)
		secondary_color = Color(0.0, 0.6, 0.9)
	else:
		# Frontflip = hot orange/gold
		primary_color = Color(1.0, 0.7, 0.1)
		secondary_color = Color(1.0, 0.4, 0.0)
	
	# Boost saturation for combos
	if flip_count >= 3:
		# Triple+ = add magenta/pink tint
		primary_color = primary_color.lerp(Color(1.0, 0.2, 0.8), 0.3)
	elif flip_count == 2:
		# Double = slightly more intense
		primary_color = primary_color.lerp(Color.WHITE, 0.2)
	
	# Apply colors
	if trick_label:
		trick_label.add_theme_color_override("font_color", primary_color)
		trick_label.add_theme_color_override("font_outline_color", secondary_color)
	
	if points_label:
		points_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.4))
		points_label.add_theme_color_override("font_outline_color", Color(0.0, 0.5, 0.2))
	
	if combo_label:
		combo_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		combo_label.add_theme_color_override("font_outline_color", Color(0.8, 0.5, 0.0))
