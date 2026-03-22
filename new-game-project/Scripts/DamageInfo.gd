extends RefCounted
class_name DamageInfo

var damage: int
var knockback: Vector2
var instigator: Node
var tags: Array[String]
var team: int

func _init(
	damage: int,
	knockback: Vector2 = Vector2.ZERO,
	instigator: Node = null,
	tags: Array[String] = [],
	team: int = 0
):
	self.damage = damage
	self.knockback = knockback
	self.instigator = instigator
	self.tags = tags.duplicate()
	self.team = team


func has_tag(tag: String) -> bool:
	return tag in tags
