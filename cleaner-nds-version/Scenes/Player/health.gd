extends Node
class_name Health

signal damaged(info: DamageInfo)
signal died

@export var max_health: int = 3
@export var invulnerable: bool = false

var current_health: int = 0
var _is_dead: bool = false


func _ready() -> void:
	current_health = max_health


func apply_damage(info: DamageInfo) -> void:
	if _is_dead:
		return

	if invulnerable:
		return

	if info == null:
		return

	current_health -= info.damage
	current_health = max(current_health, 0)
	print(name, " took damage: ", info.damage, " hp left: ", current_health)
	damaged.emit(info)

	if current_health <= 0:
		_is_dead = true
		died.emit()


func heal(amount: int) -> void:
	if _is_dead:
		return

	if amount <= 0:
		return

	current_health = min(current_health + amount, max_health)


func is_dead() -> bool:
	return _is_dead
