extends Area2D
class_name Hurtbox

@export var health_path: NodePath

@onready var health: Health = _resolve_health()


func _resolve_health() -> Health:
	if health_path != NodePath():
		return get_node_or_null(health_path) as Health

	return get_parent().get_node_or_null("Health") as Health


func apply_hit(info: DamageInfo) -> void:
	if health == null:
		return

	health.apply_damage(info)
