extends RefCounted
class_name DamageInfo

var damage: int
var knockback: Vector2
var instigator: Node

func _init(
	damage_amount: int,
	knockback_force: Vector2 = Vector2.ZERO,
	damage_instigator: Node = null
) -> void:
	damage = damage_amount
	knockback = knockback_force
	instigator = damage_instigator
