extends Area2D
class_name HealthPickup2

@export var target_group: StringName = &"player"
@export var one_shot: bool = true
@export var play_pickup_sound: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision: CollisionShape2D = $CollisionShape2D

var _collected: bool = false

func _ready() -> void:
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
	# Common setup: player has a child node named "Health"
	var health_node := body.get_node_or_null("Health")
	if health_node is Health:
		return health_node as Health

	# Fallback: search children in case Health is nested differently
	for child in body.get_children():
		if child is Health:
			return child as Health

	return null

func _restore_to_max(health: Health) -> void:
	if health == null:
		return

	health.current_health = health.max_health

	# Optional: notify HUD or other listeners that health changed
	var info := DamageInfo.new(0, Vector2.ZERO, self, ["heal", "full_restore"])
	health.damaged.emit(info)

func _collect() -> void:
	_collected = true

	if collision:
		collision.set_deferred("disabled", true)

	visible = false

	if one_shot:
		queue_free()
