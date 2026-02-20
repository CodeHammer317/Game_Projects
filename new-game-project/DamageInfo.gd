class_name DamageInfo

var amount: int
var knockback: Vector2
var instigator: Node = null
var tags: Array[String] = []

func _init(_amount: int = 1, _knockback: Vector2 = Vector2.ZERO, _instigator: Node = null, _tags: Array[String] = []):
	amount = _amount
	knockback = _knockback
	instigator = _instigator
	tags = _tags
