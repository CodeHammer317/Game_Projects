extends RefCounted
class_name DamageInfo

var damage: int
var knockback: Vector2
var instigator: Node

func _init(damage: int, knockback: Vector2 = Vector2.ZERO, instigator: Node = null) -> void:
	self.damage = damage
	self.knockback = knockback
	self.instigator = instigator
