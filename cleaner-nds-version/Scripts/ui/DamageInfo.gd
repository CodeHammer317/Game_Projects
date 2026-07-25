extends RefCounted
class_name DamageInfo

var damage: int
var knockback: Vector2
var instigator: Node

func _init(
	damage_amount: int,
	knockback_force: Vector2 = Vector2.ZERO,
	damage_instigator: Variant = null
) -> void:
	damage = damage_amount
	knockback = knockback_force

	# Projectiles can outlive the node that fired them. Retain the instigator
	# only while the supplied Object is still a valid Node.
	if is_instance_valid(damage_instigator) and damage_instigator is Node:
		instigator = damage_instigator as Node
	else:
		instigator = null
