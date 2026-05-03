extends CanvasLayer
class_name PlayerHUD

@export var player_path: NodePath

@onready var health_bar: TextureProgressBar = $HealthBar

var player: Node = null
var health: Health = null


func _ready() -> void:
	player = get_node_or_null(player_path)
	if player == null:
		push_warning("HUD: player not found.")
		return

	health = player.get_node_or_null("Health") as Health
	if health == null:
		push_warning("HUD: player has no Health node.")
		return

	if not health.damaged.is_connected(_on_health_changed):
		health.damaged.connect(_on_health_changed)

	if not health.died.is_connected(_on_health_died):
		health.died.connect(_on_health_died)

	health_bar.min_value = 0
	health_bar.max_value = health.max_health

	call_deferred("_update_health_bar")


func _on_health_changed(_info: DamageInfo) -> void:
	_update_health_bar()


func _on_health_died() -> void:
	_update_health_bar()


func _update_health_bar() -> void:
	if health_bar == null or health == null:
		return

	health_bar.max_value = health.max_health
	health_bar.value = health.current_health

	print("HUD update -> ", health.current_health, "/", health.max_health)
