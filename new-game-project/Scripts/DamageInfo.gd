extends RefCounted
class_name DamageInfo

var damage: int
var knockback: Vector2
var instigator: Node
var tags: Array

func _init(
	damage: int,
	knockback: Vector2 = Vector2.ZERO,
	instigator: Node = null,
	tags: Array = []
):
	self.damage = damage
	self.knockback = knockback
	self.instigator = instigator
	self.tags = tags
