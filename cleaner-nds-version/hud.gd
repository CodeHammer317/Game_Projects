extends CanvasLayer
class_name HUD

@export var player_path: NodePath

@onready var health_bar: TextureProgressBar = $TextureProgressBar

var _health: Health = null


func _ready() -> void:
	var player := get_node_or_null(player_path)
	if player != null:
		_health = player.get_node_or_null("Health") as Health

	if _health != null:
		if not _health.damaged.is_connected(_on_health_changed):
			_health.damaged.connect(_on_health_changed)

		if not _health.died.is_connected(_on_health_changed):
			_health.died.connect(_on_health_changed)

	_refresh_health_bar()


func _on_health_changed(_arg = null) -> void:
	_refresh_health_bar()


func _refresh_health_bar() -> void:
	if _health == null:
		health_bar.max_value = 1
		health_bar.value = 0
		return

	health_bar.min_value = 0
	health_bar.max_value = _health.max_health
	health_bar.value = _health.current_health
