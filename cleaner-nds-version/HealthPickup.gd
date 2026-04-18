extends Area2D
class_name HealthPickup

@export var target_group: StringName = &"player"
@export var one_shot: bool = true

@onready var collision: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = $Sprite2D

var _collected: bool = false

func _ready() -> void:
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _collected:
		return

	if not body.is_in_group(target_group):
		return

	var health: Health = _find_health(body)
	if health == null:
		return

	_restore_to_max(health)
	_collect()

func _find_health(body: Node) -> Health:
	var health_node := body.get_node_or_null("Health")
	if health_node is Health:
		return health_node as Health

	for child in body.get_children():
		if child is Health:
			return child as Health

	return null

func _restore_to_max(health: Health) -> void:
	if health == null:
		return

	health.restore_full()

func _collect() -> void:
	_collected = true

	if collision != null:
		collision.set_deferred("disabled", true)

	visible = false

	if one_shot:
		queue_free()
