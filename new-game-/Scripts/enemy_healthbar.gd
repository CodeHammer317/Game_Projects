# EnemyHealthBar.gd
extends Control
@export var health_bar_offset := Vector2(0, -30) # Adjust Y as needed for your ghost sprite size
@onready var health_bar_node = $HealthBar # Reference to the TextureProgressBar

func set_health_percentage(percentage: float):
	# Ensure percentage is between 0 and 1
	health_bar_node.value = clampi(percentage, 0.0, 1.0) * health_bar_node.max_value

func set_max_health_value(max_health_val: int):
	health_bar_node.max_value = max_health_val
	health_bar_node.value = max_health_val # Set to full initially

func update_health_bar(current_health: int, max_health: int):
	if health_bar_node != null:
		health_bar_node.max_value = max_health
		health_bar_node.value = current_health
		# Optional: Make it visible when damage is taken
		# health_bar_progress.visible = true
