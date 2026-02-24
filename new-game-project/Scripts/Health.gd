# Health.gd
extends Node
class_name Health

signal damaged(info: DamageInfo)
signal died

@export var max_health: int = 3
var current_health: int = 0

func _ready() -> void:
	current_health = max_health

func apply_damage(info: DamageInfo) -> void:
	current_health -= info.amount
	emit_signal("damaged", info)

	if current_health <= 0:
		emit_signal("died")
